#!/bin/bash

# A script to download twitch videos, and extract special moments from them for further editing.
#
# Requirements:
# - youtube-dl
# - tcd (twitch chat downloader)
#
# Variables:
# - id: id of the twitch video to use
# - directory: Directory to do this all in
# - keyword: keyword to search for in the chat logs for that special moment
#
# Example:
#   ./moments.sh -i 1308141879 -d /run/media/andrewcz/Halman/Media/Thuggy/ -k '!moment'

get_moments() {
  eecho "Getting the moment lines"
  # This should get passed ID and KEYWORD as args
  local moments=()
  while read -r line; do
    local time=$(echo ${line} | cut -d '[' -f 2 | cut -d ']' -f 1)
    local user=$(echo ${line} | cut -d '<' -f 2 | cut -d '>' -f 1)
    local title=$(echo ${line} | sed "s/^.*${2} //" | sed 's/ /_/g')
    eecho "Adding moment: ${time}/${user}/${title}"
    moments+=("${time}/${user}/${title}")
  done < <(grep "${2}" "${1}.txt" )

  echo "${moments[@]}"
}


usage () {
  echo '${0} --id 123456 --directory /path/to/directory --keyword !marker'
}


eecho() {
  >&2 echo ${1}
}


parse_args() {
  # Use the classic case statement to parse the args
  for i in "$@"; do
    case ${i} in
      -i=*|--id=*)
        local ID="${i#*=}"
        shift
        ;;
      -i|--id)
        local ID="${2}"
        shift
        shift
        ;;
      -d=*|--directory=*)
        local DIRECTORY="${i#*=}"
        shift
        ;;
      -d|--directory)
        local DIRECTORY="${2}"
        shift
        shift
        ;;
      -k=*|--keyword=*)
        local KEYWORD="${i#*=}"
        shift
        ;;
      -k|--keyword)
        local KEYWORD="${2}"
        shift
        shift
        ;;
    esac
  done

  # If we didn't get any of these passed in, prompt for them now
  if [[ -z $ID ]]; then
    read -p "What is the ID of the video: " ID
  fi
  if [[ -z $DIRECTORY ]]; then
    read -p "What directory should we use for storage: " DIRECTORY
  fi
  # Add a trailing slash to the directory string if it's not there
  if [[ $DIRECTORY != */ ]]; then
    DIRECTORY="${DIRECTORY}/"
  fi
  if [[ -z $KEYWORD ]]; then
    read -p "What keyword are we looking for in the chat: " KEYWORD
  fi

  echo "$ID $DIRECTORY $KEYWORD"
}

main() {
  # Set args to an array of args.
  #
  # This will always come back:
  #   args[0] = ID
  #   args[1] = DIRECTORY
  #   args[2] = KEYWORD
  args=($(parse_args ${@}))

  # Make the directory that we will be working in, and cd to it
  # saving the previous working directory
  cd ${args[1]}
  mkdir -p ${args[0]}
  cd ${args[0]}
  eecho "Creating files in ${args[1]}${args[0]}"

  #
  # Actually download the video here.
  #
  # This should provide progress information in stdout
  #
  # This gets saved as the id number with a .mp4 extension
  #
  #if [[ ! -f ${args[0]}.mp4 ]]; then
  #  youtube-dl "https://www.twitch.tv/videos/${args[0]}" -o ${args[0]}.mp4
  #fi

  #
  # Next we download the chat logs
  #
  # This gets saved as the id number with a .txt extension
  #
  # So we don't download it if it's already there
  if [[ ! -f ${args[0]}.txt ]]; then
    tcd --video ${args[0]}
  fi

  # Here we're passing ID, KEYWORD
  local moments=($(get_moments ${args[0]} ${args[2]}))
  eecho "Moments: ${moments[@]}"

  for moment in "${moments[@]}"; do
    # Get the time of the marker minus 5 minutes
    local startsecs=$(( $(date -d "${moment%/*/*}" "+%s") - $(date -d "00:05:00" "+%s") ))
    local starttime=$(echo "$((startsecs/3600)):$((startsecs%3600/60)):$((startsecs%60))")
    local momenttitle=$(echo ${moment} | cut -d '/' -f 3-)

    # Cut the video up in a 10-minute clip starting 5 minutes before the marker, and 5 minuntes after
    ffmpeg -ss ${starttime} -i "${args[1]}/${args[0]}/${args[0]}.mp4" -t 00:10:00 -c copy -y "${momenttitle}.mp4"
    eecho "Created ${momenttitle}.mp4"
  done
}

if [[ ${0%.sh} =~ 'moments' ]]; then
  main ${@} || eecho "Could not run main" && exit 2
  eecho "Completed Main"
fi
