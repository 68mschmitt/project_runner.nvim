# project_runner.nvim

**Easily define, organize, and run project commands or command groups (“compounds”) in Neovim, each in its own terminal split.**  
Project commands run in the context of their chosen directory, with compound groups supporting multi-project orchestration—all without cluttering your workspace.

---

## ✨ Features

- **Run any project command** (build, test, dev server, etc) from anywhere in Neovim
- **Compounds**: Run a group of projects’ commands in sequence, each in its own buffer within a single split
- **Interactive dialogs** for adding projects or compounds
- **Terminal auto-scroll** and focus management
- **One-liner to kill all project terminals and close splits**

---

## 🚀 Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "68mschmitt/project_runner.nvim",
  config = function()
    require("project_runner").setup({
      split_size = 10, -- Optional: terminal split height (default 10)
    })
  end,
}
```

With [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  "68mschmitt/project_runner.nvim",
  config = function()
    require("project_runner").setup({ split_size = 10 })
  end,
}
```

---

## ⚙️ Configuration

### `split_size`

- **Type:** integer  
- **Default:** `10`  
- **Description:** Sets the height (in lines) of the split where terminal sessions open.

```lua
require("project_runner").setup({
  split_size = 15, -- Set to your preferred split height
})
```

---

## 🖥️ Usage

All commands are available as Neovim user commands (and can be mapped as you wish):

### `:ProjectRunnerAdd`
- **Interactively add a new Project or Compound.**
  - Projects have: `name`, `directory`, and `command`
  - Compounds have: `name`, and a list of projects (by name) to include

### `:ProjectRunnerSelect`
- **Select and run any project or compound from a menu.**
  - Projects: Opens a split and runs your command in its specified directory
  - Compounds: Opens a single split and runs all selected projects, each in a buffer

### `:ProjectRunnerKillAll`
- **Stop all project_runner terminal jobs and close their splits/buffers.**
  - Useful for quick cleanup!

---

## 📂 Example Workflow

1. **Add a project:**  
   Run `:ProjectRunnerAdd`, choose “Project”, and enter its name, directory, and command.

2. **Add a compound:**  
   Run `:ProjectRunnerAdd`, choose “Compound”, give it a name, and select projects to include.

3. **Run a project or compound:**  
   Use `:ProjectRunnerSelect` and pick from your list!

4. **Clean up:**  
   Run `:ProjectRunnerKillAll` to stop all terminals and close their windows.

---

## 📝 Example `runners.lua` (Auto-generated Config)

Your projects and compounds are saved in a file at  
`${XDG_DATA_HOME}/nvim/project_runner/runners.lua`  
and look like this:

```lua
return {
  projects = {
    { name = "MyApp", dir = "~/dev/myapp", command = "npm run dev" },
    { name = "Backend", dir = "~/dev/api", command = "dotnet run" },
  },
  compounds = {
    { name = "All", projects = { "MyApp", "Backend" } },
  }
}
```

---

## 💡 Pro Tips

- **Buffers are reused:** Compounds run all their projects in buffers within a single split (use `:ls` and `:bnext` to switch).
- **Terminals auto-scroll:** Output is always tailed—no manual scrolling.
- **Split focus:** After launch, your cursor/focus returns to your editing window.
- **Killing jobs is aggressive:** All project_runner terminal jobs and splits are closed—perfect for a fast reset.

---

## 🛠️ Roadmap

- [ ] Add support for per-project env vars and arguments
- [ ] Optional vertical splits or tabs
- [ ] Custom actions on success/failure

---

## 📃 License

MIT

---

## 🙏 Thanks

Thanks to the Neovim community for endless inspiration!
