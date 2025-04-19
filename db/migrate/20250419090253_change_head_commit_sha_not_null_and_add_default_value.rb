class ChangeHeadCommitShaNotNullAndAddDefaultValue < ActiveRecord::Migration[8.0]
  def change
    Recipe.where(head_commit_sha: nil).update_all(head_commit_sha: "unknown")

    change_column_default :recipes, :head_commit_sha, from: nil, to: "unknown"
    change_column_null :recipes, :head_commit_sha, false
  end
end
