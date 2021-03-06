class TrackedBranchesController < DashboardController
  include Controllers::EnsureProject

  before_action :authorize_resource!

  def new
    manager = RepositoryManager.new(current_project)

    @response_data = manager.fetch_branches
  end

  def create
    tracked_branch = current_project.
      tracked_branches.create(branch_name: params[:branch_name])

    if tracked_branch.persisted?
      manager = RepositoryManager.new(tracked_branch.project)
      test_run =
        manager.create_test_run!({ tracked_branch_id: tracked_branch.id })

      if test_run
        flash[:notice] =
          "Successfully started tracking '#{tracked_branch.branch_name}' branch."
      else
        tracked_branch.destroy!
        flash[:alert] = manager.errors.join(', ')
      end
    else
      flash[:alert] = tracked_branch.errors.full_messages.join(', ')
    end

    redirect_to project_test_runs_path(current_project, branch: tracked_branch.try(:branch_name))
  end

  def destroy
    tracked_branch = current_project.tracked_branches.find(params[:id])
    if tracked_branch.destroy
      flash[:notice] = "#{tracked_branch.branch_name} branch was removed"
      redirect_to project_path(current_project)
    else
      flash[:alert] = "Can't remove #{tracked_branch.branch_name} branch"
      redirect_to project_branch_path(current_project, tracked_branch)
    end
  end

  def fetch_branches
    head :bad_request and return unless request.xhr?

    manager = RepositoryManager.new(current_project)
    @response_data = manager.fetch_branches(params[:page])

    render :new, layout: false
  end

  private

  def branch_params
    params.require(:tracked_branch).permit(:branch_name)
  end

  def authorize_resource!
    action_map = {
      new: :read,
      fetch_branches: :read,
      create: :create,
      destroy: :destroy
    }

    authorize!(action_map[action_name.to_sym], TrackedBranch)
  end
end
