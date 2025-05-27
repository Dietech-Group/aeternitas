module Aeternitas
  # Sources can store polling results in a write once - read many fashion.
  # Each source, by default, hereby stores it's raw_content in a compressed file on disk if it has not been saved yet
  # (determined by the raw_contents MD5 Hash)
  # The 'aeternitas_sources' table holds all source metadata in a quite space-efficient way. For instance the compressed
  # file's location is determined from the sources fingerprint which at the same time is it's database ID.
  class Source < ActiveRecord::Base
    ######
    # create_table :aeternitas_sources, id: :string, primary_key: :fingerprint do |t|
    #   t.string :pollable_type, null: false
    #   t.integer :pollable_id, null: false
    #   t.datetime :created_at
    # end
    # add_index :aeternitas_sources, [:pollable_id, :pollable_type], name: 'aeternitas_pollable_source'
    ######
    self.table_name = "aeternitas_sources"

    attr_writer :raw_content

    belongs_to :pollable, polymorphic: true

    after_initialize :ensure_fingerprint

    validates :raw_content, presence: true, on: :create
    validates :fingerprint, presence: true, uniqueness: true

    # Ensure that the file was created before the record is saved
    before_create :create_file

    # Make sure to delete the file if the transaction that includes the creation is aborted
    after_rollback :delete_file, on: :create

    # Make sure to delete the file only if the record was safely destroyed
    after_commit :delete_file, on: :destroy

    # Generates the entries fingerprint.
    # @return [String] the entries fingerprint.
    def generate_fingerprint
      Digest::MD5.hexdigest(@raw_content.to_s)
    end

    # Get the sources raw content.
    # @return [String] the sources raw content
    def raw_content
      @raw_content ||= Aeternitas.config.get_storage_adapter.retrieve(fingerprint)
    end

    private

    def create_file
      Aeternitas.config.get_storage_adapter.store(fingerprint, raw_content)
    end

    def delete_file
      Aeternitas.config.get_storage_adapter.delete(fingerprint)
    end

    def ensure_fingerprint
      self.fingerprint ||= generate_fingerprint
    end
  end
end
