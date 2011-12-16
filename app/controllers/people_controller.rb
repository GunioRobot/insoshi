class PeopleController < ApplicationController

  skip_before_filter :require_activation, :only => :verify
  skip_before_filter :admin_warning, :only => [ :show, :update ]
  before_filter :login_required, :only => [ :edit, :update ]
  before_filter :correct_user_required, :only => [ :edit, :update ]
  before_filter :setup

  def index
    @people = Person.active(params[:page])

    respond_to do |format|
      format.html
    end
  end

  def show
    @person = Person.find(params[:id], :include => :activities)
    if @person.deactivated?
      flash[:error] = "That person is not activated"
      redirect_to home_url and return
    end
    if logged_in?
      @some_contacts = @person.some_contacts
      @common_connections = current_person.common_connections_with(@person)
    end
    respond_to do |format|
      format.html
    end
  end

  def new
    @body = "register single-col"
    @person = Person.new

    respond_to do |format|
      format.html
    end
  end

  def create
    cookies.delete :auth_token
    @person = Person.new(params[:person])
    respond_to do |format|
      if @person.save
        self.current_person = @person
        if global_prefs.email_verifications?
          # TODO: move some of this into models.
          @person.deactivated = true; @person.save!
          @verification = EmailVerification.create(:person => @person)
          @person.email_verifications << @verification
          flash[:notice] = %(Thanks for signing up! A verification email has
                             been sent to #{@person.email}.)
          format.html { redirect_to(home_url) }
        else
          flash[:notice] = "Thanks for signing up!"
          format.html { redirect_back_or_default(home_url) }
        end
      else
        @body = "register single-col"
        format.html { render :action => 'new' }
      end
    end
  end

  def verify
    verification = EmailVerification.find_by_code(params[:id])
    if verification.nil?
      flash[:error] = "Invalid email verification code"
      redirect_to home_url
    else
      verification.person.deactivated = false; verification.person.save!
      flash[:success] = "Email verified. Your profile is active!"
      redirect_to verification.person
    end
  end

  def edit
    @person = Person.find(params[:id])

    respond_to do |format|
      format.html
    end
  end

  def update
    @person = Person.find(params[:id])
    respond_to do |format|
      case params[:type]
      when 'info_edit'
        if @person.update_attributes(params[:person])
          flash[:success] = 'Profile updated!'
          format.html { redirect_to(@person) }
        else
          format.html { render :action => "edit" }
        end
      when 'password_edit'
        if @person.change_password?(params[:person])
          flash[:success] = 'Password changed.'
          format.html { redirect_to(@person) }
        else
          format.html { render :action => "edit" }
        end
      end
    end
  end

  def common_contacts
    @person = Person.find(params[:id])
    @common_connections = @person.common_connections_with(current_person,
                                                          params[:page])
    respond_to do |format|
      format.html
    end
  end

  private

    def setup
      @body = "person"
    end

    def correct_user_required
      redirect_to home_url unless Person.find(params[:id]) == current_person
    end
end
