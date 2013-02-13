# encoding: utf-8
class Registration < BaseService
  attr_reader :organisation, :user

  attribute :name     , String
  attribute :tenant   , String
  attribute :email    , String
  attribute :password , String

  validates :name, presence: true, length: {within: 2..100}

  validates :tenant, presence: true, length: {within: 2..50}, format: {with: /\A[a-z0-9]+\z/}
  validate :valid_unique_tenant

  validates :password, presence: true, confirmation: true, length: {within: PASSWORD_LENGTH..100}
  validates_presence_of :password_confirmation
  validates_email_format_of :email

  def register
    return false unless valid?

    commit_or_rollback do
      res = create_organisation
      res = create_user && res
    end
  end

private
  def create_user
    @user = User.new(email: email, password: password)
    @user.set_confirmation_token
    @user.links.build(organisation_id: organisation.id, tenant: organisation.tenant,
                      rol: 'admin', active: true, master_account: true)
    @user.save
  end

  def create_organisation
    @organisation = Organisation.new(name: name, tenant: tenant)
    @organisation.save
  end

  def valid_unique_tenant
    if Organisation.where(tenant: tenant.to_s).any?
      self.errors[:tenant] << I18n.t('errors.messages.registration.unique_tenant')
    end
  end
end