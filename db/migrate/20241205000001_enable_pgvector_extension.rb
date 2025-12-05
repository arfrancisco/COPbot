class EnablePgvectorExtension < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'pgvector'
  end
end

