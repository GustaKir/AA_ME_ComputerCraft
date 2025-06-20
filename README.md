# Advanced Storage System

A ComputerCraft storage and crafting system that combines the best features of multiple systems:
- ARTIST's robust inventory management
- Create mod automation
- Advanced Peripherals integration
- Recursive crafting capabilities

## Features

- **Smart Storage Management**
  - Efficient item storage and retrieval
  - Automatic inventory scanning and updates
  - Support for multiple storage chests
  - Item counting and tracking

- **Advanced Crafting**
  - Recursive crafting with requirement trees
  - Create mod integration for automation
  - Support for different crafting methods:
    - Mechanical crafting
    - Mixing
    - Pressing
    - Crushing
  - Task monitoring and progress tracking

- **User Interface**
  - Simple but functional menu system
  - Item search and filtering
  - Crafting queue management
  - Task monitoring
  - Item dumping

## Setup

1. Place the computer with these requirements:
   - ComputerCraft: Tweaked
   - Advanced Peripherals
   - Create mod

2. Connect the following peripherals:
   - Storage chests (any inventory)
   - Create mod machines
   - Input/output chests

3. Edit `.artist.d/config.lua` to configure:
   - Storage chests
   - Create mod interfaces
   - Input/output locations

4. Create recipes in `crafting/recipes.json` following this format:
```json
{
  "recipes": [
    {
      "output": "minecraft:iron_ingot",
      "count": 1,
      "inputs": [
        {"item": "minecraft:iron_ore", "count": 1}
      ],
      "method": "create_crushing"
    }
  ]
}
```

## Usage

1. Run `startup.lua` to start the system

2. Main menu options:
   - **Search**: Find and extract items
   - **Craft**: Request item crafting
   - **Dump**: Add items to storage
   - **Tasks**: Monitor crafting progress

## Architecture

The system is built on several components:

- **ARTIST Core**: Handles inventory management and item tracking
- **Crafting System**: Manages recipes and automation
- **Create Integration**: Interfaces with Create mod machines
- **User Interface**: Combines all components into a usable interface

## Credits

This system combines code and concepts from:
- ARTIST (A Rather Tremendous Item SysTem)
- Inventory Manager
- OCC Remote
- Create Mod integration 