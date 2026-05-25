package cli

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var (
	cfgFile     string
	apiEndpoint string
	apiKey      string
	verbose     bool
	version     = "0.1.0"
)

type CLI struct {
	rootCmd   *cobra.Command
	logger    *slog.Logger
	viper     *viper.Viper
	apiClient *APIClient
}

type APIClient struct {
	Endpoint string
	APIKey   string
}

func NewCLI() *CLI {
	c := &CLI{
		viper: viper.New(),
	}
	c.initRootCmd()
	return c
}

func (c *CLI) initRootCmd() {
	c.rootCmd = &cobra.Command{
		Use:   "dgsnctl",
		Short: "Decentralized Ground Station Network CLI",
		Long: `dgsnctl is the command line interface for managing the Decentralized Ground Station Network.

It provides commands for:
- Station management (register, list, get, update, delete)
- Receipt management (create, verify, list, export)
- Schedule management (create, list, assign, release)
- Quantum computing (submit circuits, get results)`,
		Version: version,
		PersistentPreRun: func(cmd *cobra.Command, args []string) {
			c.initConfig()
			c.initLogger()
			c.initAPIClient()
		},
	}

	c.rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.dgsnctl.yaml)")
	c.rootCmd.PersistentFlags().StringVarP(&apiEndpoint, "endpoint", "e", "", "API endpoint URL (default: http://localhost:8080)")
	c.rootCmd.PersistentFlags().StringVarP(&apiKey, "api-key", "k", "", "API key for authentication")
	c.rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "Enable verbose output")

	c.viper.BindPFlag("endpoint", c.rootCmd.PersistentFlags().Lookup("endpoint"))
	c.viper.BindPFlag("api_key", c.rootCmd.PersistentFlags().Lookup("api-key"))
	c.viper.BindPFlag("verbose", c.rootCmd.PersistentFlags().Lookup("verbose"))

	c.rootCmd.AddCommand(c.newStationCmd())
	c.rootCmd.AddCommand(c.newReceiptCmd())
	c.rootCmd.AddCommand(c.newQuantumCmd())
	c.rootCmd.AddCommand(c.newScheduleCmd())
	c.rootCmd.AddCommand(c.newCompletionCmd())
	c.rootCmd.AddCommand(c.newConfigCmd())
}

func (c *CLI) initConfig() {
	if cfgFile != "" {
		c.viper.SetConfigFile(cfgFile)
	} else {
		home, err := os.UserHomeDir()
		if err != nil {
			fmt.Fprintln(os.Stderr, "Error finding home directory:", err)
			os.Exit(1)
		}

		c.viper.AddConfigPath(home)
		c.viper.AddConfigPath(".")
		c.viper.SetConfigType("yaml")
		c.viper.SetConfigName(".dgsnctl")
	}

	c.viper.SetEnvPrefix("DGSN")
	c.viper.AutomaticEnv()
	c.viper.SetEnvKeyReplacer(strings.NewReplacer("-", "_"))

	if err := c.viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			fmt.Fprintln(os.Stderr, "Error reading config file:", err)
			os.Exit(1)
		}
	}

	if !c.viper.IsSet("endpoint") {
		c.viper.Set("endpoint", "http://localhost:8080")
	}
}

func (c *CLI) initLogger() {
	logLevel := slog.LevelInfo
	if c.viper.GetBool("verbose") {
		logLevel = slog.LevelDebug
	}

	c.logger = slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{
		Level: logLevel,
	}))
}

func (c *CLI) initAPIClient() {
	c.apiClient = &APIClient{
		Endpoint: c.viper.GetString("endpoint"),
		APIKey:   c.viper.GetString("api_key"),
	}

	if c.apiClient.Endpoint == "" {
		c.apiClient.Endpoint = "http://localhost:8080"
	}
}

func (c *CLI) Execute() error {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		select {
		case <-sigCh:
			cancel()
			fmt.Fprintln(os.Stderr, "\nReceived signal, shutting down...")
		case <-ctx.Done():
		}
	}()

	return c.rootCmd.ExecuteContext(ctx)
}

func (c *CLI) newCompletionCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "completion [bash|zsh|fish|powershell]",
		Short: "Generate completion script",
		Long: `To load completions:

Bash:
  $ source <(dgsnctl completion bash)

  To load completions for each session, execute once:
  Linux:
    $ dgsnctl completion bash > /etc/bash_completion.d/dgsnctl
  MacOS:
    $ dgsnctl completion bash > /usr/local/etc/bash_completion.d/dgsnctl

Zsh:
  If shell completion is not already enabled in your environment,
  you will need to enable it.  You can execute the following once:

  $ echo "autoload -U compinit; compinit" >> ~/.zshrc

  To load completions for each session, execute once:
  $ dgsnctl completion zsh > "${fpath[1]}/_dgsnctl"

Fish:
  $ dgsnctl completion fish | source

  To load completions for each session, execute once:
  $ dgsnctl completion fish > ~/.config/fish/completions/dgsnctl.fish
`,
		DisableFlagsInUseLine: true,
		ValidArgs:             []string{"bash", "zsh", "fish", "powershell"},
		Args:                  cobra.ExactValidArgs(1),
		Run: func(cmd *cobra.Command, args []string) {
			switch args[0] {
			case "bash":
				cmd.Root().GenBashCompletion(os.Stdout)
			case "zsh":
				cmd.Root().GenZshCompletion(os.Stdout)
			case "fish":
				cmd.Root().GenFishCompletion(os.Stdout, true)
			case "powershell":
				cmd.Root().GenPowerShellCompletionWithDesc(os.Stdout)
			}
		},
	}
	return cmd
}

func (c *CLI) newConfigCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "config",
		Short: "Manage configuration",
		Long:  "View and modify dgsnctl configuration settings",
	}

	cmd.AddCommand(&cobra.Command{
		Use:   "show",
		Short: "Show current configuration",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Printf("Config file: %s\n", c.viper.ConfigFileUsed())
			fmt.Printf("Endpoint: %s\n", c.viper.GetString("endpoint"))
			fmt.Printf("Verbose: %v\n", c.viper.GetBool("verbose"))
			if c.viper.GetString("api_key") != "" {
				fmt.Printf("API Key: ********\n")
			}
		},
	})

	cmd.AddCommand(&cobra.Command{
		Use:   "list",
		Short: "List all configuration settings",
		Run: func(cmd *cobra.Command, args []string) {
			settings := c.viper.AllSettings()
			for k, v := range settings {
				if k == "api_key" && v != nil {
					fmt.Printf("%s: ********\n", k)
				} else {
					fmt.Printf("%s: %v\n", k, v)
				}
			}
		},
	})

	return cmd
}

func (c *CLI) WaitForStatus(ctx context.Context, check func() (bool, error), interval, timeout time.Duration) error {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			done, err := check()
			if err != nil {
				return err
			}
			if done {
				return nil
			}
		}
	}
}

func Execute() error {
	return NewCLI().Execute()
}
