defmodule Hummingbird.MixProject do
  use Mix.Project

  def project do
    [
      app: :hummingbird,
      version: "0.1.0",
      elixir: "~> 1.7",
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
      start_permanent: Mix.env() == :prod
    ]
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
