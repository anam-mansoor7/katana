crumb :root do
  link "Dashboard", root_path
end

crumb :project do |project|
  if project.repository_provider != 'bare_repo'
    link project.name, project_path(project)
  else
    link project.name, nil
  end
  parent :root
end

crumb :new_invitation do |project|
  link "Invite user", new_project_user_invitation_path(project)
  parent :project_participations, project
end

crumb :settings do |project|
  link "Settings", project_settings_path(project)
  parent :project, project
end

crumb :project_files do |project|
  link "Files", project_files_path(project)
  parent :project, project
end

crumb :project_participations do |project|
  link "Users", project_participations_path(current_project)
  parent :project, project
end

crumb :builds do |project|
  link "Builds", project_test_runs_path(project)
  parent :project, project
end


crumb :test_run do |project, run|
  link "Build ##{run.run_index}", project_test_run_path(project, run)
  parent :builds, project
end

# If you want to split your breadcrumbs configuration over multiple files, you
# can create a folder named `config/breadcrumbs` and put your configuration
# files there. All *.rb files (e.g. `frontend.rb` or `products.rb`) in that
# folder are loaded and reloaded automatically when you change them, just like
# this file (`config/breadcrumbs.rb`).
