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
    name.match?(VALID_FORMAT)
  end

  def double_hyphen?
    name.include?("--")
  end

  def available?
    client = Octokit::Client.new(access_token: user.github_token)
    begin
      client.repository("#{owner}/#{name}")
      false # Repository exists
    rescue Octokit::NotFound
      true # Repository is available
    rescue Octokit::Error => e
      Rails.logger.error("GitHub API error: #{e.message}")
      raise e
    end
  end
end
