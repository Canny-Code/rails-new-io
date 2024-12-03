class Element::Null
  def displayed?
    false
  end

  def self.has_query_constraints?
    false
  end

  def self.composite_primary_key?
    nil
  end

  def self.primary_key
    "id"
  end

  def _read_attribute(attr)
    nil
  end

  def self.polymorphic_name
    "Element::Null"
  end

  def marked_for_destruction?
    false
  end
end
