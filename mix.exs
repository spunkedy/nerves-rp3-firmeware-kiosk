defmodule NervesRp3FirmewareKiosk.MixProject do
  use Mix.Project

  @github_organization "spunkedy"
  @github_repo "nerves-rp3-firmeware-kiosk"
  @app :nerves_rp3_firmeware_kiosk
  @source_url "https://github.com/#{@github_organization}/#{@github_repo}"
  @version Path.join(__DIR__, "VERSION")
           |> File.read!()
           |> String.trim()

  def project do
    [
      app: @app,
      version: @version,
      # Because we're using OTP 27, we need to enforce Elixir 1.17 or later.
      elixir: "~> 1.17",
      compilers: Mix.compilers() ++ [:nerves_package],
      nerves_package: nerves_package(),
      description: description(),
      package: package(),
      deps: deps(),
      aliases: [
        loadconfig: [&bootstrap/1],
        generate_fwup_conf: &generate_fwup_conf/1
      ],
      docs: docs()
    ]
  end

  def application do
    []
  end

  defp bootstrap(args) do
    set_target()
    Application.start(:nerves_bootstrap)
    Mix.Task.run("loadconfig", args)
  end

  def cli do
    [preferred_envs: %{docs: :docs, "hex.build": :docs, "hex.publish": :docs}]
  end

  defp nerves_package do
    [
      type: :system,
      artifact_sites: [
        {:github_releases, "#{@github_organization}/#{@github_repo}"}
      ],
      build_runner_opts: build_runner_opts(),
      platform: Nerves.System.BR,
      platform_config: [
        defconfig: "nerves_defconfig"
      ],
      # The :env key is an optional experimental feature for adding environment
      # variables to the crosscompile environment. These are intended for
      # llvm-based tooling that may need more precise processor information.
      env: [
        {"TARGET_ARCH", "arm"},
        {"TARGET_CPU", "cortex_a53"},
        {"TARGET_OS", "linux"},
        {"TARGET_ABI", "gnueabihf"},
        {"TARGET_GCC_FLAGS",
         "-mabi=aapcs-linux -mfpu=neon-fp-armv8 -marm -fstack-protector-strong -mfloat-abi=hard -mcpu=cortex-a53 -fPIE -pie -Wl,-z,now -Wl,-z,relro"}
      ],
      checksum: package_files()
    ]
  end

  defp deps do
    [
      {:nerves, "~> 1.11", runtime: false},
      {:nerves_system_br, "1.33.5", runtime: false},
      {:nerves_toolchain_armv7_nerves_linux_gnueabihf, "~> 13.2.0", runtime: false},
      {:nerves_system_linter, "~> 0.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.22", only: :docs, runtime: false}
    ]
  end

  defp description do
    """
    Nerves System - Raspberry Pi 3 kiosk: stock rpi3 portable + Wayland +
    Cog/WPE WebKit + VC4 KMS + USB Audio Class. For driving a fullscreen
    web kiosk on a Pi 3 (B/B+/Zero 2 W) with the official 7" DSI touchscreen.
    """
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      assets: %{"assets" => "./assets"},
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp package do
    [
      files: package_files(),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp package_files do
    [
      "fwup_include",
      "rootfs_overlay",
      "cmdline-a.txt",
      "cmdline-b.txt",
      "config.txt",
      "fwup-ops.conf",
      "fwup.conf.eex",
      "fwup.conf",
      "LICENSE",
      "linux-6.12.defconfig",
      "mix.exs",
      "nerves_defconfig",
      "post-build.sh",
      "post-createfs.sh",
      "ramoops-overlay.dts",
      "README.md",
      "VERSION"
    ]
  end

  defp build_runner_opts() do
    # Download source files first to get download errors right away.
    # BR2_JLEVEL=2 caps per-package parallelism — WPE WebKit's C++ units
    # can each need ~3–4 GB to compile, so unbounded parallelism OOM-kills
    # the Docker container on machines with limited container memory.
    [make_args: primary_site() ++ ["BR2_JLEVEL=2", "source", "all", "legal-info"]]
  end

  defp primary_site() do
    case System.get_env("BR2_PRIMARY_SITE") do
      nil -> []
      primary_site -> ["BR2_PRIMARY_SITE=#{primary_site}"]
    end
  end

  defp set_target() do
    if function_exported?(Mix, :target, 1) do
      apply(Mix, :target, [:target])
    else
      System.put_env("MIX_TARGET", "target")
    end
  end

  defp generate_fwup_conf(_args) do
    template_path = Path.join(__DIR__, "fwup.conf.eex")
    output_path = Path.join(__DIR__, "fwup.conf")

    Mix.shell().info("Generating fwup.conf")

    content = EEx.eval_file(template_path)
    File.write!(output_path, content)
    Mix.shell().info("Successfully generated #{output_path}")
  end
end
