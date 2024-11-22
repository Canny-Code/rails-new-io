class GithubRepositoryNameValidator
  VALID_FORMAT = /\A[a-zA-Z0-9][a-zA-Z0-9-]*(?<!-)\z/

  def initialize(name, owner)
    @name = name.to_s
    @owner = owner.to_s
  end

  def valid?
    valid_format? && double_hyphen_free? && available?
  end

  private

  def valid_format?
    @name.match?(VALID_FORMAT)
  end

  def double_hyphen_free?
    !@name.include?("--")
  end

  def available?
    client = Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
    begin
      client.repository("#{@owner}/#{@name}")
      false # Repository exists
    rescue Octokit::NotFound
      true # Repository is available
    end
  end
end
