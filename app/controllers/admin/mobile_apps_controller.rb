class Admin::MobileAppsController < Admin::AdminController
  helper_method :sort_column, :sort_direction
  respond_to :html, :xml, :json, :csv, :xls
  before_action :set_mobile_app, only: [:show, :edit, :update, :destroy,
    :archive, :publish, :request_archive, :request_publish]

  before_filter :require_admin, only: [:publish]
  # GET /mobile_apps
  # GET /mobile_apps.json
  def index
    @mobile_apps = MobileApp.where("draft_id IS NULL").includes(:official_tags,:agencies).references(:official_tags,:agencies).uniq

    if params[:platform] && params[:platform] != ""
      @mobile_apps= @mobile_apps.joins(:mobile_app_versions).where(mobile_app_versions: {platform: params[:platform]})
    end
    @platform_counts = @mobile_apps.platform_counts
    respond_to do |format|
      format.html { @mobile_apps = []}
      format.json { render "index"}
      format.csv { send_data @mobile_apps.to_csv}
    end
  end

  def mobile_apps_export
    @mobile_apps = MobileApp.where("id in (?)", params[:ids].split(",")).includes(:official_tags,:users,:agencies,:mobile_app_versions)
     respond_to do |format|
      format.csv { send_data @mobile_apps.to_csv }
    end
  end

  def datatables
    @mobile_apps = MobileApp.where("draft_id IS NULL").uniq
    respond_to do |format|
      format.json {
        render json: {
          data: @mobile_apps
        }
      }
    end
  end
  # GET /mobile_apps/1
  # GET /mobile_apps/1.json
 # def show
  #end

  # GET /mobile_apps/new
  def new
    @mobile_app = MobileApp.new
    @mobile_app.agencies << current_user.agency if current_user.agency
    @mobile_app.users << current_user
    @mobile_app.mobile_app_versions.build
  end

  # GET /mobile_apps/1/edit
  def edit
    if @mobile_app.mobile_app_versions.count == 0
      @mobile_app.mobile_app_versions.build
    end
  end

  def show

  end

  # POST /mobile_apps
  # POST /mobile_apps.json
  def create
    @mobile_app = MobileApp.new(mobile_app_params)

    respond_to do |format|
      if @mobile_app.save
        @mobile_app.build_notifications(:created)
        @mobile_app.published!
        format.html { redirect_to admin_mobile_app_path(@mobile_app), notice: 'MobileApp was successfully created.' }
        format.json { render :show, status: :created, location: @mobile_app }
      else
        if @mobile_app.mobile_app_versions.empty?
          @mobile_app.mobile_app_versions.build
        end
        format.html { render :new }
        format.json { render json: @mobile_app.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /mobile_apps/1
  # PATCH/PUT /mobile_apps/1.json
  def update
    respond_to do |format|
      if @mobile_app.update(mobile_app_params)
        @mobile_app.build_notifications(:updated)
        format.html { redirect_to admin_mobile_app_path(@mobile_app), notice: 'MobileApp was successfully updated.' }
        format.json { render :show, status: :ok, location: admin_mobile_app_path(@mobile_app) }
      else
        format.html { render :edit }
        format.json { render json: @mobile_app.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /mobile_apps/1
  # DELETE /mobile_apps/1.json
  def destroy
    @mobile_app.destroy!
    respond_to do |format|
      format.html { redirect_to admin_mobile_apps_url, notice: 'MobileApp was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def activities
    @activities = PublicActivity::Activity.where(trackable_type: "MobileApp").order("created_at desc").page(params[:page]).per(25)
  end

  def publish
    @mobile_app.published!
    @mobile_app.build_notifications(:published)
    redirect_to admin_mobile_app_path(@mobile_app), :notice => "Mobile App: #{@mobile_app.name}, is now published. #{view_context.link_to 'Undo', archive_admin_mobile_app_path(@mobile_app)}".html_safe

  end

  def archive
    @mobile_app.archived!
    @mobile_app.build_notifications(:archived)
    redirect_to admin_mobile_app_path(@mobile_app), :notice => "Mobile App: #{@mobile_app.name}, is now archived. #{view_context.link_to 'Undo', publish_admin_mobile_app_path(@mobile_app)}".html_safe
  end

  def request_publish
    @mobile_app.publish_requested!
    @mobile_app.build_notifications(:publish_requested)
    redirect_to admin_mobile_app_path(@mobile_app), :notice => "Mobile App: #{@mobile_app.name}, has a request in with admins to be published."
  end

  def request_archive
    @mobile_app.archive_requested!
    @mobile_app.build_notifications(:archive_requested)
    redirect_to admin_mobile_app_path(@mobile_app), :notice => "Mobile App: #{@mobile_app.name}, has a request in with admins to be archived."
  end

  def version_details_for_url
    @details_object = AppStore.find_details_by_url(params[:store_url])
    respond_to do |format|
      format.json { render json: @details_object }
    end
  end

   private
    # Use callbacks to share common setup or constraints between actions.
    def set_mobile_app
      @mobile_app = MobileApp.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def mobile_app_params
      params.require(:mobile_app).permit(:name, :short_description, :long_description, :icon_url,
        :language, :agency_tokens, :user_tokens, :tag_tokens, mobile_app_versions_attributes: [:id, :store_url,:platform,
        :version_number,:publish_date,:description,:whats_new,:screenshot,:device,
        :language,:average_rating,:number_of_ratings, :_destroy])
    end

    def sort_column
      MobileApp.column_names.include?(params[:sort]) ? params[:sort] : "name"
    end

    def sort_direction
      %w[asc desc].include?(params[:direction]) ? params[:direction] : "asc"
    end

    def items_per_page_handler
      per_page_count = 25
      if params[:hidden_platform_value]
        params[:platform] = params[:hidden_platform_value]
      end
      if cookies[:per_page_count_mobile_registrations]
        per_page_count = cookies[:per_page_count_mobile_registrations]
      end
      if params[:per_page]
        per_page_count = params[:per_page]
        cookies[:per_page_count_mobile_registrations] = per_page_count
      end
      return per_page_count.to_i
    end

    def get_tag(tag_id)
      !tag_id.nil? ? OfficialTag.find_by(id: tag_id) : nil
    end

    def tag_text(tag)
      !tag.nil? ? tag.tag_text : nil
    end
end
