class RequireVariantInElements < ActiveRecord::Migration[8.0]
  def change
    def change
      change_column_null :elements, :variant_type, false
      change_column_null :elements, :variant_id, false
    end
  end
end
