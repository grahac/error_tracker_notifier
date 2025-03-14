defmodule ErrorTrackerNotifier.MixProject do
  use Mix.Project

  def project do
    [
      app: :error_tracker_notifier,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Email notifications for ErrorTracker events",
      package: package()
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
      {:swoosh, "~> 1.5"},
      {:error_tracker, "~> 0.5"},
      {:telemetry, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:httpoison, "~> 2.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/grahac/error_tracker_notifier"},
      name: "error_tracker_notifier"
    ]
  end
end
