defmodule Medishop.Generator do
  use Ash.Generator

  def user(overrides \\ []) do
    Ash.Generator.changeset_generator(
      Medishop.Accounts.User,
      :register,
      defaults: [
        email: sequence(:email, &"user#{&1}@example.com"),
        password: "password"
      ],
      overrides: overrides,
      authorize?: false
    )
  end

  def organization(overrides \\ []) do
    Ash.Generator.changeset_generator(
      Medishop.Organizations.Organization,
      :create,
      defaults: [
        name: sequence(:name, &"Test Organization #{&1}")
      ],
      overrides: overrides,
      authorize?: false
    )
  end

  def organization_membership(overrides \\ []) do
    user_id =
      overrides[:user_id] ||
        user() |> Ash.Generator.generate() |> Map.get(:id)

    organization_id =
      overrides[:organization_id] ||
        organization()
        |> Ash.Generator.generate()
        |> Map.get(:id)

    Ash.Generator.changeset_generator(
      Medishop.Organizations.OrganizationMembership,
      :create,
      defaults: [
        organization_id: organization_id,
        user_id: user_id,
        org_roles: [:org_member]
      ],
      overrides: overrides,
      authorize?: false
    )
  end
end