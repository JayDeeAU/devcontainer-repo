# 📖 Documentation Index

> **Universal Development Environment**: Works identically across all your projects.

---

## 🎯 Start Here

**New to this project?** Follow these steps:

1. **Setup** (5 min): [PROJECT-SETUP.md](PROJECT-SETUP.md) - Generate `.container-config.json`
2. **Quick Start** (5 min): [QUICK-START.md](QUICK-START.md) - Learn essential commands
3. **Architecture** (15 min): [ARCHITECTURE.md](ARCHITECTURE.md) - Understand the system

**Experienced developer?** Jump to [QUICK-START.md](QUICK-START.md)

---

## 📚 Documentation Overview

### User Guides

| Document | Purpose | Time | When to Read |
|----------|---------|------|--------------|
| [PROJECT-SETUP.md](PROJECT-SETUP.md) | Project configuration | 5 min | **First time** setting up any project |
| [QUICK-START.md](QUICK-START.md) | Daily development commands | 5 min | **Day 1** - Essential workflow |
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design & integration | 15 min | **Week 1** - Deeper understanding |
| [WORKFLOWS-QUICK-REFERENCE.md](WORKFLOWS-QUICK-REFERENCE.md) | Quick workflow lookup table | Daily | **Quick lookup** - What command to use |
| [WORKFLOWS-DETAILED-GUIDE.md](WORKFLOWS-DETAILED-GUIDE.md) | Complete workflow scenarios | As needed | **Reference** - Step-by-step guides |

### Technical Documentation

| Document | Purpose | Audience |
|----------|---------|----------|
| [README.md](README.md) | DevContainer technical setup | DevOps, system admins |
| [DOCUMENTATION-SUMMARY.md](DOCUMENTATION-SUMMARY.md) | Help system overview | Documentation maintainers |

---

## 💡 Quick Help

### In Your Shell

```bash
# See all help topics
dot_help_all

# Daily workflow guide
dot_help_workflow          # or: quick-help, dev-help

# System architecture
dot_help_architecture      # or: arch-help, system-help

# Container management
dot_help_containers        # or: container-help, env-help
```

### Essential Commands

```bash
# Start a feature
gffs my-feature-name

# Commit changes
feat "add user login"

# Finish feature
gfff

# Switch environments
env-local / env-staging / env-prod

# Get help
dot_help_all
```

---

## 🎓 Learning Path

### Day 1 - Quick Start (5 minutes)
1. Generate project config: `.devcontainer/scripts/config-generator.sh default`
2. Read [QUICK-START.md](QUICK-START.md)
3. Learn commands: `gffs`, `feat`, `gfff`
4. Start coding!

### Week 1 - Environment Mastery (15 minutes)
1. Read [ARCHITECTURE.md](ARCHITECTURE.md)
2. Practice environment switching: `env-local`, `env-staging`, `env-prod`
3. Try hotfix workflow: `ghfs`, `fix`, `ghff`
4. Explore help system: `dot_help_all`

### Month 1 - Advanced Features (30 minutes)
1. Study [WORKFLOWS-DETAILED-GUIDE.md](WORKFLOWS-DETAILED-GUIDE.md)
2. Master debug modes: `env-prod-debug`, `env-staging-debug`
3. Understand version management: `gvb`, `gvs`
4. Read [README.md](README.md) for DevContainer details

---

## 🔍 Find What You Need

### By Task

**Setting up a new project**
→ [PROJECT-SETUP.md](PROJECT-SETUP.md)

**Learning daily commands**
→ [QUICK-START.md](QUICK-START.md)

**Understanding how it works**
→ [ARCHITECTURE.md](ARCHITECTURE.md)

**Debugging production**
→ [QUICK-START.md § Debugging Production](QUICK-START.md#debugging-production-issues)

**Working in parallel with team**
→ [QUICK-START.md § Parallel Development](QUICK-START.md#parallel-development-teams)

**Configuring environments**
→ [PROJECT-SETUP.md § Configuration Options](PROJECT-SETUP.md#configuration-options-explained)

**Troubleshooting issues**
→ [QUICK-START.md § When Things Go Wrong](QUICK-START.md#when-things-go-wrong)

**DevContainer setup details**
→ [README.md](README.md)

### By Role

**Developer (new)**
1. [PROJECT-SETUP.md](PROJECT-SETUP.md) - One-time setup
2. [QUICK-START.md](QUICK-START.md) - Daily workflow
3. `dot_help_workflow` - In-shell reference

**Developer (experienced)**
1. [ARCHITECTURE.md](ARCHITECTURE.md) - System design
2. [WORKFLOWS-DETAILED-GUIDE.md](WORKFLOWS-DETAILED-GUIDE.md) - Advanced scenarios
3. `dot_help_all` - Complete reference

**DevOps / Admin**
1. [README.md](README.md) - Technical setup
2. [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
3. [PROJECT-SETUP.md § Templates](PROJECT-SETUP.md#templates-explained) - Project templates

**Team Lead**
1. [ARCHITECTURE.md § Design Principles](ARCHITECTURE.md#design-principles) - Philosophy
2. [PROJECT-SETUP.md § Multi-Project Setup](PROJECT-SETUP.md#multi-project-setup) - Team workflows
3. [WORKFLOWS-DETAILED-GUIDE.md](WORKFLOWS-DETAILED-GUIDE.md) - Team scenarios

---

## 🎯 Key Concepts

### Universal System
- Same commands work across **all projects**
- Learn once, use everywhere
- MagmaBI, Project B, Project C → identical workflow

### Three-Layer Architecture
```
Dotfiles (Commands) → Container Manager (Docker) → Version Manager (Versions)
```

### Three Environments
- **Local** (7700 ports) - Active development
- **Staging** (7600 ports) - Pre-production testing
- **Production** (7500 ports) - Deployment

### Project Configuration
- One file: `.container-config.json`
- Generated via: `.devcontainer/scripts/config-generator.sh`
- Customized per project

---

## 🚀 Quick Reference Card

```
┌────────────────────────────────────────────────────┐
│  Universal Development Environment                 │
├────────────────────────────────────────────────────┤
│  📖 Documentation:                                 │
│     Setup:       PROJECT-SETUP.md                  │
│     Quick Start: QUICK-START.md                    │
│     Architecture: ARCHITECTURE.md                  │
│                                                    │
│  💬 In-Shell Help:                                 │
│     dot_help_all          # All topics             │
│     dot_help_workflow     # Daily commands         │
│     dot_help_architecture # System design          │
│     dot_help_containers   # Environments           │
│                                                    │
│  🛠️  Essential Commands:                           │
│     gffs <name>          # Start feature           │
│     feat "msg"           # Commit                  │
│     gfff                 # Finish feature          │
│     env-local            # Local environment       │
│     env-staging          # Staging environment     │
│     env-prod             # Production environment  │
│                                                    │
│  ⚙️  Setup:                                         │
│     config-generator.sh default                    │
│     universal-container-manager status             │
└────────────────────────────────────────────────────┘
```

---

## ❓ Frequently Asked Questions

**Q: Is this specific to MagmaBI?**
A: No! This is a **universal system** that works identically across all projects.

**Q: Where do I configure my project?**
A: One file: `.container-config.json` (generated via `config-generator.sh`)

**Q: What if I have multiple projects?**
A: Same dotfiles, same commands, different `.container-config.json` per project.

**Q: How do I get help?**
A: Type `dot_help_all` in your shell for instant help.

**Q: Do I need to understand all the complexity?**
A: No! Learn 5 commands on day 1, discover features over time.

---

## 🤝 Contributing

Improvements to this system benefit **all projects** using it.

Before modifying:
1. Ensure changes are universal (not project-specific)
2. Test across multiple projects
3. Update documentation
4. Maintain backward compatibility

---

## 📞 Getting Support

1. **Quick questions**: `dot_help_all` in your shell
2. **Workflow help**: Read [QUICK-START.md](QUICK-START.md)
3. **Setup issues**: Check [PROJECT-SETUP.md § Troubleshooting](PROJECT-SETUP.md#troubleshooting)
4. **Deep dive**: Study [ARCHITECTURE.md](ARCHITECTURE.md)

---

**Ready to start?** → [QUICK-START.md](QUICK-START.md)

**Need project setup?** → [PROJECT-SETUP.md](PROJECT-SETUP.md)

**Want to understand it?** → [ARCHITECTURE.md](ARCHITECTURE.md)
