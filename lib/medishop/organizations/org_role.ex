defmodule Medishop.Organizations.OrgRole do
  @moduledoc """
  Organization role enum defining the three role types: org_admin (full permissions), org_member (basic access), and org_buyer (purchasing permissions).
  """

  use Ash.Type.Enum, values: [:org_admin, :org_member, :org_buyer]
end
