class TrackedBranchesController < DashboardController
  include Controllers::EnsureProject

  def new
    if client = current_user.github_client
      @branches = client.branches(current_project.repository_id).
        reject { |b| b.name.in?(current_project.tracked_branches.map(&:branch_name)) }.
        map { |b| TrackedBranch.new(branch_name: b.name) }
    end
  end

  def create
    if branch_params[:branch_name].present? && (client = current_user.github_client)
      branch = client.branch(current_project.repository_id, branch_params[:branch_name])
      tracked_branch = current_project.tracked_branches.create!(branch_name: branch.name)

      #create a test job for the tracked branch
      head_sha = branch[:commit][:sha]
      tracked_branch.test_jobs.create!(commit_sha: head_sha, status: TestStatus::PENDING)

      flash[:notice] = "Successfull started tracking '#{tracked_branch.branch_name}' branch."
    end

    redirect_to project_path(current_project)
  end

  private
  def branch_params
    params.require(:tracked_branch).permit(:branch_name)
  end
end
