#!/bin/bash

if [ $# -lt 1 ]
then
   echo "Usage: $0 <cfg|cmd> [remote-branch]"
   exit 1
fi

CDPATH=
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

main()
{
   local CFG="$1"; shift;
   local BR="$1"; shift;

   local i
   for i in $SCRIPT_DIR/../*
   do
      if [ -d "$i/.git" ]; then
         (
            cd $i;
            _J=$( git fetch --all )
            if [ "$BR" ]
            then
               LOCAL_BRANCH=$( git branch -r | grep -w "$BR" | grep -v -e '->' | sed -e 's,^\s*,,' -e 's,/, ,' | head -1 | awk '{ print $2 }')
               REMOTE_BRANCH=$LOCAL_BRANCH
               REMOTE_NAME=
               REMOTE_URL=
               REPO_NAME=$(git remote -v | awk '{ print $2; exit; }' | xargs -n1 '-I{}' -- basename '{}' .git)
            else
               LOCAL_BRANCH=$( git branch -vv | grep '^[*]' | sed -e 's/no branch/no-branch/' | awk '{ print $2 }')
               REMOTE_BRANCH=$(git branch -vv | grep '^[*]' | grep -o '\[[^]]*\]' | sed -e 's,:.*\],],' -e 's,^.,,' -e 's,\]$,,' -e 's,[^/]*/,,')
               REMOTE_NAME=$(  git branch -vv | grep '^[*]' | grep -o '\[[^]]*\]' | sed -e 's,:.*\],],' -e 's,^.,,' -e 's,\]$,,' -e 's,/.*,,')
               REMOTE_URL=$(   git remote get-url "$REMOTE_NAME" 2>/dev/null)
               REPO_NAME=$(basename "$REMOTE_URL" .git)
            fi

            if [ "$LOCAL_BRANCH" == "(no-branch)" ] || [ -z "$LOCAL_BRANCH" ] || [ -z "$REPO_NAME" ]
            then
               continue
            fi

            if [ "$LOCAL_BRANCH" != "develop" ]
            then
               if [ "$CFG" == "cfg" ]
               then
                  echo "%GIT_OVERRIDES          = ${REPO_NAME}.branch=$LOCAL_BRANCH"
               else
                  echo "--git-overrides ${REPO_NAME}.branch=$LOCAL_BRANCH"
               fi
            fi

            if [ "$LOCAL_BRANCH" != "$REMOTE_BRANCH" ] && [ "$REMOTE_BRANCH" != "develop" ]
            then
               if [ "$CFG" == "cfg" ]
               then
                  echo "%GIT_OVERRIDES          = ${REPO_NAME}.branch=$REMOTE_BRANCH"
               else
                  echo "# --git-overrides ${REPO_NAME}.branch=$REMOTE_BRANCH"
               fi
            fi

            if [ "$REMOTE_URL" ]
            then
               if ! grep -q -e "/Zimbra" -e ":Zimbra" -e "/zimbra/" <(echo "$REMOTE_URL")
               then
                  if [ "$CFG" == "cfg" ]
                  then
                     echo "%GIT_OVERRIDES          = ${REPO_NAME}.remote=my-${REPO_NAME}-rem"
                     echo "%GIT_OVERRIDES          = my-${REPO_NAME}-rem.url-prefix=$REMOTE_URL"
                  else
                     echo "--git-overrides ${REPO_NAME}.remote=my-${REPO_NAME}-rem"
                     echo "--git-overrides my-${REPO_NAME}-rem.url-prefix=$REMOTE_URL"
                  fi
               fi
            fi
         )
      fi
   done
}

main "$@"
