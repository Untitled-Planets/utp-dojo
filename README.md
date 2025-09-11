# UTP Dojo contracts

This project implements a 3D world game on Starknet using Dojo, with players, spaceships, planets, and procedurally generated collectables.

## Toolchain

Install the toolchain using this guide [Dojo getting started](https://dojoengine.org/installation)

## Running Locally

#### Terminal one (Make sure this is running)

```bash
# Run Katana
katana --dev --dev.no-fee
```

#### Terminal two

```bash
# Build the example
sozo build

# Inspect the world
sozo inspect

# Migrate the example
sozo migrate

# Start Torii
# Replace <WORLD_ADDRESS> with the address of the deployed world from the previous step
torii --world <WORLD_ADDRESS> --http.cors_origins "*"
```

The URLs for katana and torii will be in the deployment output. The contract and world address will be in the output of `sozo inspect`.

Check the `dojo_dev.toml` file for the correct values, this is used by `sozo migrate` and `sozo execute` to deploy and test the contracts.

