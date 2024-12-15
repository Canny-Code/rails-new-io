class GithubRepositoryNameValidator
  VALID_FORMAT = /\A[a-zA-Z0-9][a-zA-Z0-9-]*(?<!-)\z/

  def initialize(name, owner)
    @name = name
    @owner = owner
  end

  def repo_exists?
    return false unless valid_format?
    return false if double_hyphen?
    !available?
  end

  private

  attr_reader :name, :owner

  def valid_format?
    return false if name.nil?
    name.match?(VALID_FORMAT)
  end

  def double_hyphen?
    name.to_s.include?("--")
  end

  def available?
    client = Octokit::Client.new
    begin
      exists = client.repository?("#{owner}/#{name}")
      !exists # Return true if repo doesn't exist
    rescue Octokit::Error => e
      Rails.logger.error("GitHub API error: #{e.message}")
      raise e
    end
  end
end
