defmodule Medishop.Accounts.User do
  @moduledoc """
  User resource for authentication and authorization.

  Users can authenticate via email and password, with support for magic link authentication.
  Users belong to organizations through organization memberships.
  """
  use Ash.Resource,
    otp_app: :medishop,
    domain: Medishop.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end
    end

    tokens do
      enabled? true
      token_resource Medishop.Accounts.Token
      signing_secret Medishop.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      password do
        identity_field :email
        registration_enabled? true
      end
    end
  end

  postgres do
    table "users"
    repo Medishop.Repo
  end

  actions do
    defaults [:read]

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :get_by_email do
      description "Looks up a user by their email"
      argument :email, :ci_string, allow_nil?: false
      get_by :email
    end

    create :register do
      primary? true
      accept [:email]
      argument :password, :string, sensitive?: true, allow_nil?: false
      change set_context(%{strategy_name: :password})
      change AshAuthentication.Strategy.Password.HashPasswordChange
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action(:sign_in_with_password) do
      authorize_if always()
    end

    policy action(:register) do
      authorize_if always()
    end

    policy action(:read) do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? true
      sensitive? true
    end
  end

  relationships do
    has_many :organization_memberships, Medishop.Organizations.OrganizationMembership

    has_many :orders, Medishop.Shop.Order do
      public? true
    end
  end

  identities do
    identity :unique_email, [:email]
  end
end
