# encoding: utf-8
# author: Boris Barroso
# email: boriscyber@gmail.com
class Payment < BaseService
  attr_reader :ledger, :int_ledger, :transaction

  # Attributes
  attribute :account_id, Integer
  attribute :account_to_id, Integer
  attribute :date, Date
  attribute :amount, Decimal, default: 0
  attribute :exchange_rate, Decimal, default: 1
  attribute :reference, String
  attribute :verification, Boolean, default: false

  # Validations
  validates_presence_of :account_id, :account_to, :account_to_id, :reference, :date
  validates_numericality_of :amount, greater_than: 0
  validates_numericality_of :exchange_rate, greater_than: 0
  validate :valid_date
  validate :valid_accounts_currency

  delegate :currency, :inverse?, :same_currency?, to: :currency_exchange

  # Initializes and sets verification to false if it's not set correctly
  def initialize(attrs = {})
    super
    self.verification = false unless [true, false].include?(verification)
  end

  def account_to
    @account_to ||= Account.active.find_by_id(account_to_id)
  end

private
  # Builds and AccountLedger instance with some default data
  def build_ledger(attrs = {})
    AccountLedger.new({
      account_id: account_id, exchange_rate: conv_exchange_rate,
      account_to_id: account_to_id, inverse: inverse?,
      reference: reference, date: date, currency: account_to.currency
    }.merge(attrs))
  end

  # Inverse of verification?, no need to negate when working making more
  # readable code
  def conciliate?
    !verification?
  end

  def valid_date
    self.errors.add(:date, I18n.t('errors.messages.payment.date') ) unless date.is_a?(Date)
  end

  def set_approver
    unless transaction.is_approved?
      transaction.approver_id = UserSession.id
      transaction.approver_datetime = Time.zone.now
    end
  end

  def valid_accounts_currency
    unless currency_exchange.valid?
      self.errors.add(:base, I18n.t('errors.messages.payment.valid_accounts_currency', currency: currency))
    end
  end

  def currency_exchange
    @currency_exchange ||= CurrencyExchange.new(
      account: transaction, account_to: account_to, exchange_rate: exchange_rate
    )
  end

  def amount_exchange
    currency_exchange.exchange(amount)
  end

  # Exchange rate used using inverse
  def conv_exchange_rate
    currency_exchange.exchange_rate
  end

  def current_organisation
    OrganisationSession
  end

  # Indicates conciliation based on the type of account
  def conciliation?
    return true if conciliate?

    account_to.is_a?(Bank) ? conciliate? : true
  end

end
