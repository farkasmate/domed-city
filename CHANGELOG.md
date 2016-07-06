# 3.0.1

Forcibly unsetting environment variables `AWS_ACCESS_KEY` and `AWS_SECRET_KEY`.
This is to prevent bypassing the user's local credentials specified in `~/.aws/credentials`.

Fixed bug where `dome --state` needed to be called first when setting up a new environment.
This requires some further testing but we may wish to remove this CLI option in the future.

# 3.0.0

Thanks to [@Russell-IO](https://github.com/Russell-IO) for helping with these changes.

- Internal refactoring.
- More tests added (but lots more needed).
- Improved debug output and explained up front how variables are set.
- Removed `aws_profile_parser` and used environment variables instead to unify
the AWS CLI and terraform calls.

ROADMAP:
- Merge [@mhlias](https://github.com/mhlias) changes that implements assumed-role support.
