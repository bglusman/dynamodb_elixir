defmodule Dynamodb.Mixfile do
  use Mix.Project

  def project do
    [app: :dynamodb,
     version: "0.1.2-dev",
     elixir: "~> 1.0",
     deps: deps,
     name: "Dynamodb",
     source_url: "https://github.com/bglusman/dynamodb_elixir",
     docs: fn ->
       {ref, 0} = System.cmd("git", ["rev-parse", "--verify", "--quiet", "HEAD"])
       [source_ref: ref, main: "readme", extras: ["README.md"]]
     end,
     description: description,
     package: package]
  end

  def application do
    [applications: [:logger, :connection],
     mod: {Dynamo, []},
     env: []]
  end

  defp deps do
    [{:connection, "~> 1.0"},
     {:poolboy,    "~> 1.5", optional: true},
     {:ex_doc,     ">= 0.0.0", only: :docs},
     {:earmark,    ">= 0.0.0", only: :docs},
     {:inch_ex,    ">= 0.0.0", only: :docs}]
  end

  defp description do
    "DynamoDB driver for Elixir."
  end

  defp package do
    [maintainers: ["Brian Glusman"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/bglusman/dynamodb_elixir"}]
  end
end
