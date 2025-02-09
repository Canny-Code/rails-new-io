class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def wtf
    errors.full_messages.to_sentence
  end
end
