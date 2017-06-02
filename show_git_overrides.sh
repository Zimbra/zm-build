#!/bin/bash

CDPATH=
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

main()
{
   local CFG="$1"; shift;

   local i
   for i in $SCRIPT_DIR/../*
   do
      if [ -d "$i/.git" ]; then
         (
            cd $i;
            LOCAL_BRANCH=$( git branch -vv | grep '^[*]' | sed -e 's/no branch/no-branch/' | awk '{ print $2 }')
            REMOTE_NAME=$(  git branch -vv | grep '^[*]' | grep -o '\[[^]]*\]' | sed -e 's,:.*\],],' -e 's,^.,,' -e 's,\]$,,' -e 's,/.*,,')
            REMOTE_BRANCH=$(git branch -vv | grep '^[*]' | grep -o '\[[^]]*\]' | sed -e 's,:.*\],],' -e 's,^.,,' -e 's,\]$,,' -e 's,.*/,,')
            REMOTE_URL=$(   git remote get-url "$REMOTE_NAME" 2>/dev/null)

            if [ "$LOCAL_BRANCH" == "(no-branch)" ] || [ -z "$REMOTE_NAME" ]
            then
               continue
            fi

            if [ "$LOCAL_BRANCH" != "develop" ]
            then
               if [ "$CFG" ]
               then
                  echo "%GIT_OVERRIDES          = $(basename "$REMOTE_URL" .git).branch=$LOCAL_BRANCH"
               else
                  echo "--git-overrides '$(basename "$REMOTE_URL" .git).branch=$LOCAL_BRANCH'"
               fi
            fi

            if [ "$LOCAL_BRANCH" != "$REMOTE_BRANCH" ] && [ "$REMOTE_BRANCH" != "develop" ]
            then
               if [ "$CFG" ]
               then
                  echo "%GIT_OVERRIDES          = $(basename "$REMOTE_URL" .git).branch=$REMOTE_BRANCH"
               else
                  echo "# --git-overrides '$(basename "$REMOTE_URL" .git).branch=$REMOTE_BRANCH'"
               fi
            fi

            if ! grep -q -e "/Zimbra" -e ":Zimbra" -e "/zimbra/" <(echo "$REMOTE_URL")
            then
               if [ "$CFG" ]
               then
                  echo "%GIT_OVERRIDES          = $(basename "$REMOTE_URL" .git).remote=my-$(basename "$REMOTE_URL" .git)-rem"
                  echo "%GIT_OVERRIDES          = my-$(basename "$REMOTE_URL" .git)-rem.url-prefix=$REMOTE_URL"
               else
                  echo "--git-overrides '$(basename "$REMOTE_URL" .git).remote=my-$(basename "$REMOTE_URL" .git)-rem'"
                  echo "--git-overrides 'my-$(basename "$REMOTE_URL" .git)-rem.url-prefix=$REMOTE_URL'"
               fi
            fi
         )
      fi
   done
}

main "$@"
