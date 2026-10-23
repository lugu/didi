# Didi Mod for Luanti

The `didi` mod adds custom blocks, items, and AI-powered building commands to Luanti (Minetest / VoxeLibre).

---

## Requirements

1. Enable HTTP access for the `didi` mod.
2. Open your `~/.minetest/minetest.conf` file.
3. Add the following line to the file:
   ```ini
   secure.http_mods = didi
   ```
4. Restart Luanti.

---

## How to Get a Google Gemini API Key

You must have a Google Gemini API key to use the `/god` command.

1. Open [https://aistudio.google.com/](https://aistudio.google.com/) in your web browser.
2. Sign in with your Google account.
3. Click the **"Create API key"** button.
4. Copy the generated API key.
5. Save the API key in one of two ways:
   - **In-game**: Run `/god_key <your_api_key>` in the chat.
   - **File**: Paste the key into `~/.minetest/mods/didi/gemini_key.txt`.

---

## Permissions

The `/god` commands require the `god` privilege. This privilege is disabled by default.

- To grant the `god` privilege to a player, run:
  ```text
  /grant <player_name> god
  ```
- To grant the `god` privilege to yourself in singleplayer, run:
  ```text
  /grantme god
  ```
- To remove the `god` privilege from a player, run:
  ```text
  /revoke <player_name> god
  ```

---

## Available `/god` Commands

| Command | Description |
| :--- | :--- |
| `/god <request>` | Sends your request to the LLM to build structures or cast magic in front of you. |
| `/god_key <api_key>` | Saves the Google Gemini API key in the mod storage. |
| `/god_undo` | Reverts the last `/god` action (restores blocks and removes spawned entities). |
| `/god_reset` | Clears your conversation history with the LLM. |

---

## How the `/god` Command Works

1. **Origin Capture**: When you run `/god <request>`, the mod records your current position and look direction. You can move while the LLM processes your request. The build always appears at your initial position.
2. **World Context Scan**: The mod scans the terrain in front of you. It measures the ground height, identifies surface blocks, and detects the block you look at.
3. **Multi-Turn Memory**: The mod sends your request, the terrain data, and the last 5 turns of your conversation to the Google Gemini API.
4. **Lua Code Generation**: The LLM outputs Lua code that uses relative coordinates:
   - `f` (forward): distance in front of you.
   - `u` (up): vertical height from your feet.
   - `r` (right): distance to your left or right.
5. **Safe Execution and Undo**: The mod records all original blocks before it runs the generated Lua code. This lets you run `/god_undo` to restore the world at any time.

---

## Run Unit Tests

To run the unit tests for the `/god` system, execute:

```bash
lua test_llm.lua
```
