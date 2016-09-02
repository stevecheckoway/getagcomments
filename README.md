GetAutogradeComments
====================

This application uses the GitHub API to scan a GitHub organization's
repositories that match a given regular expression and extracts comments on
certain commits. The intention is to extract auto-grader comments left on
students' commits in a GitHub Classrooms assignment.

Preliminaries
-------------

GitHub classrooms create a repo per assignment for each student or team. The
repo name is the [slugified](https://en.wikipedia.org/wiki/Semantic_URL#Slug)
form of the assignment name and the student/team name. For example,
assignments "Project 1" and "Project 2" with teams "Able", "Baker", and
"Charlie" in the GitHub organization "cs-1" would have the following
corresponding repositories.

- `cs-1/project-1-able`
- `cs-1/project-1-baker`
- `cs-1/project-1-charlie`
- `cs-1/project-2-able`
- `cs-1/project-2-baker`
- `cs-1/project-2-charlie`

GetAutogradeComments assumes that when students push changes to a special
branch (e.g., a `submission` branch), an auto-grader is run and the results of
the auto-grader are left as comments on the commit corresponding to the head
of the given branch by a GitHub machine account. When it comes time to record
grades, running GetAutogradeComments will extract all of those comments.

Instructions
------------

1. Setup [GitHub classrooms](https://classroom.github.com).
2. Create a GitHub machine user account (which is just a normal account).
3. Make the machine user an administrator of the organization being used as
   the classroom.
4. Set up the auto-grader to leave comments on student's submissions using the
   machine user. (This may involve creating a personal access token.)
5. Log into the machine user's account and create a personal access token by
   going to `Settings > Personal access tokens > Generate new token`. Give
   the token a description and select `repo` and `read:org` scopes. Click
   "Generate token" and copy the 40-character token.
6. For each assignment, create a simple [YAML](http://yaml.org/) file with the
   following fields.

       token:        40-char personal access token
       organization: example_org
       assignment:   project-1
       branch:       submission
7. Run `getagcomments.rb`, passing the path to the assignment YAML file.
