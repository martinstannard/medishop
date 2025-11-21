defmodule Medishop.Organizations.OrgRole do
  use Ash.Type.Enum, values: [:org_admin, :org_member, :org_buyer]
end
