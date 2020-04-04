
# Open Access Button API

This repo will automatically deploy changes committed to the API. There is a develop branch and a master branch.
Changes MUST be committed to the develop branch first and tested on the dev API. Once confirmed as being acceptable, 
they can be committed to the master branch. Master does not yet autoamtically deploy - it could do, but will be checked 
manually for now.

This API code is a "plugin" for a larger API infrastructure. More details and docs to follow.


## Contributing

Discussion and issues happen for this project and others on OAB in the discussion repo: [issues/discussion area](https://github.com/OAButton/discussion)


## How to Edit via GitHub command line

- Clone the repository and switch to `develop` branch.

  ```sh
  git clone git@github.com:OAButton/API.git
  git checkout develop
  ```

- Edit the files as you see fit, create new files as necessary.
- You can use the status command to check what branch you are on, and what changes you have ready to commit.

  ```sh
  git status
  git add .
  git commit -am 'I edited these files, yay me - or some more useful message'
  git pull origin develop
  ```

- If others have made changes there may be some merge fixes to make after the `git pull` - if so, fix them.

  ```sh
  git push origin develop
  ```

- Check the test site to see that things look how you want (there may be a couple of minutes delay).

  ```sh
  git checkout master
  git merge origin/develop
  ```

- Again, check for any merge conflict warnings and fix them.

  ```sh
  git pull origin master
  ```

- Quick check for any more changes made by others, fix any conflicts, then push the merge.

  ```sh
  git push origin master
  ```

- Now your changes are on the live site too!
- Switch back to `develop` branch ready to do more editing

  ```sh
  git checkout develop
  ```

## Approval Process

This keeps branches aligned and ensures content on the sight is properly vetted.

* Anyone with at least "contributor access" (_i.e._ permission to push) can commit to `develop` branch to test changes
* Mark to approve change
* Mark merges on to `master`

If branches get out of alignment, Mark needs to review.
