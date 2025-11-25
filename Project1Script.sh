#!/bin/bash

PROJECT_DIR=~/UNIGAP/Project1
OUTPUT_FILE="$PROJECT_DIR/tmdb-movies.csv"
DATA_URL="https://raw.githubusercontent.com/yinghaoz1/tmdb-movie-dataset-analysis/master/tmdb-movies.csv"

if [ ! -d "$PROJECT_DIR" ]; then
  mkdir ~/UNIGAP/Project1
fi

wget -O "$OUTPUT_FILE" "$DATA_URL"

cd "$PROJECT_DIR"

# dùng dấu " làm quy tắc cắt chuỗi kí tự, một dòng CSV sẽ bị chia nhỏ theo quy luật Lẻ/Chẵn
# Chuỗi chẵn: là chuỗi bắt đầu sau lần đầu xuất hiện dấu ", sau đó kết thúc khi gặp một dấu " nữa. Tiếp tục lặp lại các quy tắc đó để tìm ra những chuỗi được đặt trong "..."
# Chuỗi lẻ: là chuỗi đầu tiên cho đến trước khi xuất hiện dấu " và các trường hợp còn lại
awk 'BEGIN{FS=OFS="\""} {
    for (i=2; i<=NF; i+=2) {
        gsub(",", "###", $i)
    }
    print $0
}' tmdb-movies.csv > movies_cleaned.csv

#================================================================
#1.Sắp xếp các bộ phim theo ngày phát hành giảm dần rồi lưu ra một file mới
# Lấy header ra
head -n 1 movies_cleaned.csv > sorted_movies.csv

# Lấy dữ liệu từ dòng thứ 2 trở đi
tail -n +2 movies_cleaned.csv | \
# Xử lý lại các dữ liệu dạng ngày, thêm số 0 vào đầu những ngày/tháng chỉ có một chữ số
sed -E -e "s/,([0-9])\//,0\1\//g" -e "s/\/([0-9])\//\/0\1\//g" | \
# Xử lý ghép thành chuỗi dạng ngày hoàn chỉnh sắp xếp
awk -F',' '{
    # Cắt lấy 2 ký tự đầu tiên của cột 16 làm Tháng
    month = substr($16, 1, 2);
    
    # Cắt lấy 2 ký tự từ vị trí số 4 của cột 16 làm Ngày
    day = substr($16, 4, 2);
    
    # Lấy Năm từ cột 19
    $16 = $19 "-" month "-" day;

    print $0;
  }' OFS=',' | \
sort -t',' -k16r >> sorted_movies.csv

#================================================================
#2. Lọc ra các bộ phim có đánh giá trung bình trên 7.5 rồi lưu ra một file mới
# Lấy header ra
head -n 1 movies_cleaned.csv | \
# Lấy dữ liệu từ dòng thứ 2 trở đi
tail -n +2 | \
# lấy những dữ liệu có giá trị vote_average > 7.5
awk -F',' '$18 > 7.5' movies_cleaned.csv > highrated_movies.csv

#================================================================
#3. Tìm ra phim nào có doanh thu cao nhất và doanh thu thấp nhất
tail -n +2 movies_cleaned.csv | sort -t',' -k5n | head -n 1 | awk -F',' '{print "--- Doanh thu thấp nhất: " $6 " ---"}'
tail -n +2 movies_cleaned.csv | sort -t',' -k5nr | head -n 1 | awk -F',' '{print "--- Doanh thu cao nhất: " $6 " ---"}'

#================================================================
#4. Tính tổng doanh thu tất cả các bộ phim
awk -F',' '{sum += $5} END {print "--- Tổng doanh thu tất cả: " sum " ---"}' movies_cleaned.csv

#================================================================
#5. Top 10 bộ phim đem về lợi nhuận cao nhất
echo "--- Top 10 bộ phim đem về lợi nhuận cao nhất ---"
tail -n +2 movies_cleaned.csv | \
awk -F',' '{
    title = $6
    budget = $5
    revenue = $4
    profit = budget - revenue
    print title, profit}' OFS='|'| \
sort -t'|' -k2nr | \
head -n 10 | \
cut -d'|' -f1

#================================================================
#6. Đạo diễn nào có nhiều bộ phim nhất và diễn viên nào đóng nhiều phim nhất
echo "--- Đạo diễn nhiều bộ phim nhất ---"
tail -n +2 movies_cleaned.csv | \
# Lấy riêng dữ liệu cột đạo diễn, bỏ đi cột nào NULL
awk -F',' '$9 != "" {print $9}' | \
# Lấy số lần xuất hiện của tên đạo diễn ở đầu mỗi dòng
sort | uniq -c | \
# Tìm ra đạo diễn xuất hiện nhiều lần nhất
sort -nr | head -n 1 | sed -E 's/^( *)[0-9]* //'

# Lấy số lần xuất hiện diễn viên ở đầu mỗi dòng
echo "--- Diễn viên đóng nhiều bộ phim nhất ---"
tail -n +2 movies_cleaned.csv | \
# Lấy riêng dữ liệu cột diễn viên, bỏ đi cột nào NULL
awk -F',' '$7 != "" {print $7}' | \
# Thay thế kí hiệu | bằng xuống dòng
tr '|' '\n' | \
# Lấy số lần xuất hiện của tên diễn viên ở đầu mỗi dòng
sort | uniq -c | \
# Tìm ra diễn viên xuất hiện nhiều lần nhất
sort -nr | head -n 1 | sed -E 's/^( *)[0-9]* //'

#================================================================
#7. Thống kê số lượng phim theo các thể loại. Ví dụ có bao nhiêu phim thuộc thể loại Action, bao nhiêu thuộc thể loại Family, ...
echo "--- Thống kê số lượng phim theo các thể loại ---"
tail -n +2 movies_cleaned.csv | \
# Lấy riêng dữ liệu cột thể loại, bỏ đi cột nào NULL
awk -F',' '$14 != "" {print $14}' | \
# Thay thế kí hiệu | bằng xuống dòng
tr '|' '\n' | \
# Tìm ra danh sách số lượng phim theo các thể loại
sort | uniq -c | sort -nr

#================================================================
#8. Idea của bạn để có thêm những phân tích cho dữ liệu?
# Sử dụng cột keywords để xem xu hướng phim hiện tại là gì
# Chọn ra phim có thời lượng dài nhất/ngắn nhất, sử dụng cột runtime
# Thống kê xem studio nào sản xuất nhiều phim nhất, hoặc studio nào có doanh thu cao nhất, ...