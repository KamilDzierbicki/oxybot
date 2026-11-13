# Integrations, users, AI settings and team-wide instructions change how the whole account works: admins only
module AdminOnly
  extend ActiveSupport::Concern

  class_methods do
    def admin_only(**options)
      before_action :require_admin, **options
    end
  end

  private

  def require_admin
    head :forbidden unless Current.user&.admin?
  end
end
