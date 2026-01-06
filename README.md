# bukidbayan_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

_____________________________________________________________________________________

# 📘 Capstone Git Workflow Guide

This guide explains **how to work on your tasks safely** using feature branches, dev integration, and pull requests.

1. Branches Overview

| Branch      | Purpose                                                                 |
| ----------- | ----------------------------------------------------------------------- |
| `main`      | Stable, demo-ready, submission branch — do NOT work directly here       |
| `dev`       | Integration/testing branch — all feature branches are merged here first |
| `feature/*` | Individual tasks (one branch per feature)                               |

**Feature branch naming convention:**

```
feature/<feature-name>-<role>
```

Examples:

```
feature/login-frontend
feature/login-backend
feature/profile-frontend
feature/profile-backend
```

---

2. Workflow Steps

### Step 1: Set up local repo

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO
flutter pub get   # to get dependencies
```

Switch to the dev branch:

```bash
git checkout dev
git pull origin dev
```

---

### Step 2: Create your feature branch

Branch from dev:

```bash
git checkout -b feature/<your-feature>-<role>
```

> Example:

```bash
git checkout -b feature/login-frontend
```

---

### Step 3: Code and commit

Work on your task normally. Commit **frequently** with meaningful messages:

```bash
git add .
git commit -m "Add login screen UI"
```

---

### Step 4: Push your feature branch

```bash
git push -u origin feature/<your-feature>-<role>
```

* This uploads your branch to GitHub
* You only need `-u` the first time; future pushes can use `git push`

---

### Step 5: Create a Pull Request (PR)

1. Go to GitHub → **Pull Requests** → **New Pull Request**
2. Base branch = `dev`
3. Compare branch = your feature branch
4. Title = clear description of your feature
5. Description = short summary of changes
6. Create PR → assign teammates to review (optional)

> **Do NOT merge PRs directly into main**

---

Absolutely! Let’s add the **exact Git commands** for each of these steps so your collaborators can **copy-paste safely**. I’ll rewrite Step 6 with the commands included:

---

### Step 6: Testing and Merging (with Git commands)

1. **Backend merges first → dev (usually be also creates first)**

```bash
# Switch to dev branch
git checkout dev

# Pull latest changes from remote dev
git pull origin dev

# Merge backend feature branch into dev
git merge feature/login-backend   # replace with your backend branch name

# Push dev to GitHub
git push origin dev
```

2. **Frontend pulls dev to test against backend**

```bash
# Switch to your frontend feature branch
git checkout feature/login-frontend  # replace with your frontend branch

# Pull latest dev (with backend code) into your branch
git pull origin dev

# Now you can run/test FE with BE locally
```

3. **Once everything works → frontend merges PR into dev**

```bash
# Switch to dev branch
git checkout dev

# Merge frontend branch into dev
git merge feature/login-frontend  # replace with your frontend branch

# Push dev to GitHub
git push origin dev
```

4. **Dev now has integrated FE + BE**
   
6. **Once dev is stable → merge dev → main**

```bash
# Switch to main branch
git checkout main

# Pull latest from remote main
git pull origin main

# Merge dev into main
git merge dev

# Push main to GitHub
git push origin main
```

---

💡 Notes / Tips:

* Replace `feature/login-frontend` and `feature/login-backend` with the actual branch names your team uses.
* Always **pull latest dev/main before merging** to avoid conflicts.
* Keep `main` stable — only merge after dev is fully tested.

---

If you want, I can **update your full README** with **all steps + commands for cloning, branching, committing, pushing, and PRs**, so your whole team has **one copy-paste-ready workflow**.

Do you want me to do that?

---

### Step 7: Clean up

After merging:

```bash
git checkout dev
git pull origin dev
git branch -d feature/<your-feature>-<role>
```

* Deletes local branch (keep repo clean)
* GitHub can also delete the remote branch after PR merge

---

## 3️⃣ General Rules

1. **Never work directly on `main`**
2. **Always branch from `dev`**
3. **Commit small and often**
4. **PRs must be reviewed** (or at least tested) before merging
5. **Pull latest dev frequently** to avoid conflicts:

```bash
git checkout feature/<your-feature>-<role>
git pull origin dev
```

---

## 4️⃣ Branching Example for Our Capstone

```text
main (stable)
   ↑
dev (integration/testing)
   ↑
feature/login-backend
feature/login-frontend
feature/profile-backend
feature/profile-frontend
```
