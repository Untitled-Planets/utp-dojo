# Dojo Game Contract

This project implements a 3D world game on Starknet using Dojo, with players, spaceships, planets, and procedurally generated collectables.

## 🧰 Requirements

- [Scarb](https://docs.swmansion.com/scarb/)
- [Dojo CLI (sozo)](https://book.dojoengine.org/)
- [Katana](https://book.dojoengine.org/tools/katana/)

Install all tools:
```bash
curl -L https://install.dojoengine.org | bash
````

## 🚀 Getting Started

### 0. Install Dependencies (1.7.0-alpha.1)
From the installation guide at https://book.dojoengine.org/getting-started/installation/ 

```bash
asdf plugin add katana https://github.com/dojoengine/asdf-katana.git
asdf plugin add torii https://github.com/dojoengine/asdf-torii.git
asdf plugin add sozo https://github.com/dojoengine/asdf-sozo.git

asdf install scarb nightly-2025-05-08
```

Create a `.tools-versions` file containing the follwing:
```bash
scarb nightly-2025-05-08
sozo 1.7.0-alpha.1
katana 1.7.0-alpha.3
torii 1.7.0-alpha.3
```

### 1. Start Local Devnet

```bash
katana
```

### 2. Build Contract

```bash
./scripts/build.sh
```

### 3. Deploy World + Systems

```bash
./scripts/deploy.sh
```

## 🗂 Project Structure

* `src/components.cairo` – Position and Direction components
* `src/models.cairo` – Models for players, spaceships, planets
* `src/GameActions.cairo` – Action implementations
* `src/IGameActions.cairo` – ABI interface
* `src/world.cairo` – World model logic

## ✨ Features

* Player and spaceship movement in 3D
* Planets with gravity radius and seeds
* Reference body switching
* Procedural collectable generation per area
* Inventory and item pickup

## For more information about 1.7.0-alpha.1 migration, visit https://book.dojoengine.org/migration/1.7.0-alpha.1/

