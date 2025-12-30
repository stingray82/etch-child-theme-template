# Etch Child Theme Template

This repository provides a **base Etch child theme template** with **automatic update support** built in.

It is designed for developers who manage multiple WordPress sites and want a **clean, repeatable workflow** for maintaining child themes with reliable update delivery.

---

## Purpose

This repository is intended to be:

- Cloned into **multiple separate repositories**
- Each repository representing **one individual site**
- Maintained independently while sharing a common update mechanism

Rather than using one monolithic theme for all sites, this approach keeps each site isolated while still benefiting from a standardized update system.

---

## Automatic Updates (UUPD)

This template integrates **UUPD (Universal Update Delivery)**, allowing the child theme to:

- Serve updates from:
  - Public GitHub repositories
  - Private GitHub repositories
  - Private/self-hosted update servers
- Maintain a **remote update index** for each site
- Support controlled, versioned releases

The update logic is already hooked into `functions.php` and is ready for **site-specific customization**.

---

## Repository Structure

Each cloned repository typically contains:

- The child theme files
- A `uupd/` directory containing update metadata
- Deployment scripts:
  - `.bat` (Windows)
  - `.sh` (macOS/Linux)
  - `.cfg` configuration file

These scripts automate:

- Version handling
- Update index generation
- Git commits and tagging
- Release creation and asset uploads

---

## Customisation

You are expected to:

- Modify the child theme as required for the site
- Adjust update logic inside `functions.php` if needed
- Edit the deployment scripts and configuration files per project

This template is intentionally flexible rather than opinionated.

---

## Important Notes

When releasing updates, **always remember to**:

- Update the **static** file
- Update the **changelog**
- Bump the theme version before deploying

Failing to do so may result in incorrect or stale update information being served.

---

## Typical Workflow

1. Clone this repository for a new site
2. Customize the child theme
3. Configure update settings
4. Commit changes and bump the version
5. Deploy using the provided scripts
6. Deliver updates via UUPD

---

## License

This project follows the same licensing terms as the Etch parent theme and WordPress GPL compatibility.

---

**This repository is a template — clone it, customize it, and make it your own.**
