#!/bin/bash
# Crawl all subfolders of the EE26 recordings drive
declare -A FOLDERS=(
  ["1dskvFmorIgFjIaGKxliS4AbIDB9ZBgvk"]="Environments of Tomorrow Track"
  ["1FlJE7IYSsSllXKOlUwFZBkMbHhCKkuTV"]="Fri June 5, 2026"
  ["1-eERcKosivsZc4IDu0zOE9rYSWN6vV3y"]="Fri. June 12, 2026"
  ["11fb-o4o2qNg5Yayf3xvm4YFkgtn7CjG1"]="Fri. June 19, 2026"
  ["1V-AdVTwbZV2pyE7noiWC1QcfzbGq9JEm"]="Fri. June 26th, 2026"
  ["1M8rvozLZ0_O-JaSase4hGMqMD_j8H6cJ"]="Future of Education Track"
  ["1jh9nazUDCm4e-Dqw7mpbAJeIogEwHFD_"]="Mon June 1, 2026"
  ["11E3M29claG3X_VEFdSXR3pLQ9EkHt87v"]="Mon. June 15th, 2026"
  ["1_npeWL4flyiWpcibwzfuNe4nE-PP1HoL"]="Mon. June 22, 2026"
  ["1YAHOFE7vVuXRlg7F_w0kaO7140S6lFNy"]="Mon. June 8, 2026"
  ["1tCd6dq82G4LE-rCag9N4ZK1rcQ_QCacd"]="Orly Talk"
  ["1NYyNe0biLJXijb5QtKA75KIqal8pR8P4"]="Sat. June 13, 2026"
  ["1TstndG-hYV6cmxMPrxBf0MZSL4QrRjrr"]="Sat. June 20, 2026"
  ["1TqANyD2D1Z91fGe0MAGXaeRWPl4EpPY-"]="Sat. June 27, 2026"
  ["12nGR6LpNcZNCyDVs8o88IzqprLfpwgfk"]="Sat. June 6, 2026"
  ["19mz_kdnB8sfSMgnkGnv-kFfyUoIl5TxA"]="Sun May 31, 2026"
  ["1ZEmQymPRbSf5fnv5ZAPIppQOd-KkR0vE"]="Sun. June 14, 2026"
  ["19tEf3hAkN4vqWfp_HsEoFpXkl4Lquo2n"]="Sun. June 21, 2026"
  ["1vCz7HceIiP2D53JM5XqCCLFAWeKpi36o"]="Sun. June 7, 2026"
  ["1xpL5clL3CJsJt9lQ9IW-8esU7HcjMVwe"]="Thur June 4, 2026"
  ["1y4fE587VGQT1zD1_2hIYnyoqs_ehMpi4"]="Thur. June 11, 2026"
  ["1fLJYUxbwhX3aIA4lujcdmFoiPdecSYTu"]="Thurs. June 18, 2026"
  ["1rtXUL0vsC8eBmyFVlml5yk2L8rt2lQWc"]="Thurs. June 25, 2026"
  ["13OuYQoIyg1TlFXOnmJW3U7GVvzQu6DDS"]="Transcripts"
  ["1uOSPb0XKparoLd0TfsQC6Y6KxX8A9kyZ"]="Tue June 2, 2026"
  ["1XRAQsT2eMiWn55EzBUmoU60qskxvrOya"]="Tue. June 16, 2026"
  ["1F4cB21OaHr9sJpODClRePCTLiZKvW7ns"]="Tue. June 23, 2026"
  ["1To1ZVcEMvWjoD1zPcOeMw_XWfb2_OHjv"]="Tue. June 9, 2026"
  ["1pNugrIZ3jJVgR0kxvZB4HlC005-Pymmi"]="Wed June 3, 2026"
  ["1eQtyyTbNAcELJ_MGsLDWiDSIHAJ7XkL3"]="Wed. June 10, 2026"
  ["1Ra7oGWyzmERbIjEaNS6kYXwBM7pZ8FJL"]="Wed. June 17, 2026"
  ["1eZX9Q-zNNSpaXFt9sIc5FbhsV_YIMgpY"]="Wed. June 24, 2026"
)
OUT=/workspace/edgetv-build/raw
mkdir -p "$OUT"
for id in "${!FOLDERS[@]}"; do
  curl -s "https://drive.google.com/embeddedfolderview?id=${id}#list" -o "$OUT/${id}.html" &
done
wait
echo "done: $(ls $OUT | wc -l) folder listings"
