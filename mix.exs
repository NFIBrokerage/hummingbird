defmodule Hummingbird.MixProject do
  use Mix.Project

  @version_file Path.join(__DIR__, ".library_version")

  # a special module attribute that recompiles if targetted file has changed
  @external_resource @version_file

  @version (case Regex.run(~r/^v([\d\.]+)/, File.read!(@version_file), capture: :all_but_first) do
              [version] -> version
              nil -> "0.0.0"
            end)

  def project do
    [
      app: :hummingbird,
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        credo: :test,
        dialyzer: :test,
        bless: :test
      ],
      dialyzer: [ignore_warnings: ".dialyzer.ignore_warnings"],
      test_coverage: [tool: ExCoveralls],
      package: package(),
      description: description(),
      source_url: "https://github.com/NFIBrokerage/hummingbird",
      name: "Hummingbird"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/fixtures"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      name: "hummingbird",
      files: ~w(lib .formatter.exs mix.exs README.md),
      licenses: [],
      # Removed as we're publishing this to the public package repository for
      # the rest of the world to use.
      #
      # organization: "cuatro",
      links: %{"GitHub" => "https://github.com/NFIBrokerage/hummingbird"}
    ]
  end

  defp description do
    "honeycomb.io Phoenix plug to assist in tracing"
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:plug, "~> 1.7"},
      {:elixir_uuid, "~> 1.2"},
      {:opencensus_honeycomb, "~> 0.2.1"},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.11", only: :test}
    ]
  end

  defp aliases do
    [
      bless: [&bless/1]
    ]
  end

  defp bless(_) do
    [
      {"compile", ["--force", "--warnings-as-errors"]},
      {"coveralls.html", []},
      {"format", ["--check-formatted"]},
      {"credo", []},
      {"dialyzer", []}
    ]
    |> Enum.each(fn {task, args} ->
      [:cyan, "Running #{task} with args #{inspect(args)}"]
      |> IO.ANSI.format()
      |> IO.puts()

      Mix.Task.run(task, args)
    end)
  end
end
