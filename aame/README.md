# AA_ME Storage System

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
    - Compacting
    - Haunting
    - Milling
    - Deploying
    - Spout filling
  - Task monitoring and progress tracking

- **User Interface**
  - Clean and intuitive menu system
  - Item search and filtering
  - Crafting queue management
  - Task monitoring
  - System statistics
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

3. Edit `config.json` to configure:
   - Storage chests
   - Create mod interfaces
   - Input/output locations

4. Create recipes in `data/recipes.json` following this format:
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
   - **Settings**: Configure system
   - **Exit**: Shut down system

## Architecture

The system is built with a modular design:

- **Core**
  - `inventory.lua`: Item storage and tracking
  - `crafting.lua`: Recipe management and automation
  - `config.lua`: System configuration

- **Peripherals**
  - `manager.lua`: Peripheral detection and management
  - `create.lua`: Create mod machine interfaces

- **Interface**
  - `main.lua`: User interface and menus

- **Library**
  - `log.lua`: Logging utilities

## Credits

This system combines code and concepts from:
- ARTIST (A Rather Tremendous Item SysTem)
- Inventory Manager
- OCC Remote
- Create Mod integration

## License

MIT License - Feel free to use and modify as needed. 