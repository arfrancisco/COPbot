class ConvertToVectorEmbeddings < ActiveRecord::Migration[7.0]
  def up
    # Enable pgvector extension
    enable_extension 'vector'

    # Add new vector column (1536 dims to support HNSW indexing)
    add_column :messages, :embedding_vector, :vector, limit: 1536

    # Copy existing JSONB embeddings to vector format
    # Note: This will be empty initially - run regenerate_embeddings.rb after this migration
    execute <<-SQL
      UPDATE messages
      SET embedding_vector = (
        SELECT array_agg((embedding->idx)::text::float ORDER BY idx)::vector
        FROM generate_series(0, jsonb_array_length(embedding) - 1) AS idx
      )
      WHERE embedding IS NOT NULL
      AND jsonb_array_length(embedding) = 1536
    SQL

    # Remove the old GIN index on JSONB embedding
    remove_index :messages, :embedding

    # Add HNSW index for ultra-fast vector similarity search
    # HNSW is the fastest option and scales well to 100k+ messages
    # Using 1536 dimensions (reduced from 3072) to stay under the 2000 dim limit
    add_index :messages, :embedding_vector, using: :hnsw, opclass: :vector_cosine_ops

    # Remove old JSONB column (optional - you can keep it for backup)
    # Uncomment the line below if you want to remove it
    # remove_column :messages, :embedding
  end

  def down
    # Restore JSONB column if removed
    # add_column :messages, :embedding, :jsonb unless column_exists?(:messages, :embedding)

    # Copy vector back to JSONB
    execute <<-SQL
      UPDATE messages
      SET embedding = (
        SELECT jsonb_agg(embedding_vector[idx])
        FROM generate_series(1, array_length(embedding_vector, 1)) AS idx
      )
      WHERE embedding_vector IS NOT NULL
    SQL

    # Remove vector index and column
    remove_index :messages, :embedding_vector
    remove_column :messages, :embedding_vector

    # Re-add GIN index on JSONB
    add_index :messages, :embedding, using: :gin

    # Disable pgvector extension
    disable_extension 'vector'
  end
end
