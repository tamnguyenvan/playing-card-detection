#include <stdio.h>
#include <math.h>
#include <opencv2/opencv.hpp>
#include <chrono>
#include <stdexcept>

#if defined(WIN32) || defined(_WIN32) || defined(__WIN32)
#define IS_WIN32
#endif

#ifdef __ANDROID__
#include <android/log.h>
#endif

#ifdef IS_WIN32
#include <windows.h>
#endif

#if defined(__GNUC__)
    // Attributes to prevent 'unused' function from being removed and to make it visible
    #define FUNCTION_ATTRIBUTE __attribute__((visibility("default"))) __attribute__((used))
#elif defined(_MSC_VER)
    // Marking a function for export
    #define FUNCTION_ATTRIBUTE __declspec(dllexport)
#endif

#define CORNER_WIDTH 32
#define CORNER_HEIGHT 84

// Dimensions of rank train images
#define RANK_WIDTH 70
#define RANK_HEIGHT 73

// Dimensions of suit train images
#define SUIT_WIDTH 70
#define SUIT_HEIGHT 80

// Transformed card size
#define CARD_WIDTH 200
#define CARD_HEIGHT 300

#define CARD_MIN_AREA 30
#define CARD_MAX_AREA 5


using namespace cv;
using namespace std;

long long int get_now() {
    return chrono::duration_cast<std::chrono::milliseconds>(
            chrono::system_clock::now().time_since_epoch()
    ).count();
}

void platform_log(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
#ifdef __ANDROID__
    __android_log_vprint(ANDROID_LOG_VERBOSE, "ndk", fmt, args);
#elif defined(IS_WIN32)
    char *buf = new char[4096];
    std::fill_n(buf, 4096, '\0');
    _vsprintf_p(buf, 4096, fmt, args);
    OutputDebugStringA(buf);
    delete[] buf;
#else
    vprintf(fmt, args);
#endif
    va_end(args);
}

// Avoiding name mangling
extern "C" {
    const vector<string> SUITS{"c", "d", "h", "s"};
    const string DEFAULT_SUIT = "unk";
    const string DEFAULT_RANK = "unk";
    const int32_t NUM_RANKS = 13;
    const int32_t NUM_RANK_TYPES = 2;
    const int32_t NUM_SUITS = 4;
    const int32_t NUM_SUIT_TYPES = 2;

    FUNCTION_ATTRIBUTE
    const char* version() {
        return CV_VERSION;
    }

    class QueryCard {
        public:
            vector<Point> contour;
            Rect box;
            vector<Point> corners;
            Point center;
            Mat warped;
    };

    bool sort_by_y_axis_asc(const Point& a, const Point& b) {
        return a.y < b.y;
    }

    bool sort_by_x_axis_asc(const Point& a, const Point& b) {
        return a.x < b.x;
    }
    bool sort_by_x_axis_desc(const Point& a, const Point& b) {
        return a.x > b.x;
    }

    void find_four_points(vector<Point> points, vector<Point>& out) {
        vector<int> sum_values(points.size());
        for (size_t i = 0; i < points.size(); i++)
        {
            sum_values[i] = points[i].x + points[i].y;
        }
        Point tl, br;
        const auto minmax = minmax_element(sum_values.begin(), sum_values.end());
        const int min_index = distance(sum_values.begin(), minmax.first);
        const int max_index = distance(sum_values.begin(), minmax.second);
        tl = points[min_index];
        br = points[max_index];

        vector<int> diff_values(points.size());
        for (size_t i = 0; i < points.size(); i++)
        {
            diff_values[i] = points[i].y - points[i].x;
        }
        Point tr, bl;
        const auto minmax_diff = minmax_element(diff_values.begin(), diff_values.end());
        const int min_index_diff = distance(diff_values.begin(), minmax_diff.first);
        const int max_index_diff = distance(diff_values.begin(), minmax_diff.second);
        tr = points[min_index_diff];
        bl = points[max_index_diff];

        vector<Point> ret{tl, tr, br, bl};
        out = ret;
    }

    void transform_image(Mat image, Mat &out, vector<Point> points, int width, int height) {
        vector<Point> four_points;
        find_four_points(points, four_points);
        Point2f temp_rect[4];

        // If card is vertically oriented
        if (width <= 0.8 * height) {
            temp_rect[0] = four_points[0];
            temp_rect[1] = four_points[1];
            temp_rect[2] = four_points[2];
            temp_rect[3] = four_points[3];
        }

        // If card is horizontally oriented
        if (width > 1.2 * height) {
            temp_rect[0] = four_points[3];
            temp_rect[1] = four_points[0];
            temp_rect[2] = four_points[1];
            temp_rect[3] = four_points[2];
        }

        if ((width > 0.8 * height) && (width < 1.2 * height)) {
            if (points[1].y <= points[3].y) {
                temp_rect[0] = points[1];
                temp_rect[1] = points[0];
                temp_rect[2] = points[3];
                temp_rect[3] = points[2];
            }

            if (points[1].y > points[3].y) {
                temp_rect[0] = points[0];
                temp_rect[1] = points[3];
                temp_rect[2] = points[2];
                temp_rect[3] = points[1];
            }
        }

        Point2f dst[4];
        dst[0] = Point(0, 0);
        dst[1] = Point(CARD_WIDTH-1, 0);
        dst[2] = Point(CARD_WIDTH-1, CARD_HEIGHT-1);
        dst[3] = Point(0, CARD_HEIGHT-1);
        Mat M = getPerspectiveTransform(temp_rect, dst);
        Mat warped;
        warpPerspective(image, warped, M, Size(CARD_WIDTH, CARD_HEIGHT));
        cvtColor(warped, warped, COLOR_BGR2GRAY);

        threshold(warped, out, 0, 255, THRESH_BINARY_INV | THRESH_OTSU);
    }

    // comparison function object
    bool compare_contour_areas(std::vector<cv::Point> contour1, std::vector<cv::Point> contour2) {
        double i = fabs(contourArea(cv::Mat(contour1)));
        double j = fabs(contourArea(cv::Mat(contour2)));
        return i > j;
    }

    void preprocess_image(vector<Point> contour, Mat image, QueryCard &q_card) {
        q_card.contour = contour;

        double peri = arcLength(contour, true);
        vector<Point> points;
        approxPolyDP(contour, points, 0.01*peri, true);
        q_card.corners = points;

        Rect card_box = boundingRect(contour);
        q_card.box = card_box;

        int center_x, center_y;
        center_x = card_box.x + card_box.width / 2;
        center_y = card_box.y + card_box.height / 2;
        q_card.center = Point(center_x, center_y);

        // transform the card
        Mat warped;
        transform_image(image, warped, points, card_box.width, card_box.height);
        q_card.warped = warped;
        flip(q_card.warped, q_card.warped, -1);
    }


    void match_rank(Mat image, vector<Mat> rank_images, uint32_t &output_rank, double &output_rank_val, double max_val_thresh=0.5) {
        double rank_val = 0.;
        uint32_t rank = 0;
        for (size_t i = 0; i < NUM_RANKS; i++)
        {
            for (size_t j = 0; j < NUM_RANK_TYPES; j++)
            {
                // string templ_name = assets_dir + "/rank_" + to_string(i+1) + "_" + to_string(j) + ".JPG";
                // Mat templ = imread(templ_name, IMREAD_GRAYSCALE);
                Mat rgb_templ = rank_images[i*NUM_RANK_TYPES+j];
                Mat templ;
                cvtColor(rgb_templ, templ, COLOR_BGR2GRAY);

                Mat result;
                matchTemplate(image, templ, result, TM_CCOEFF_NORMED);

                double min_val, max_val;
                Point min_idx, max_idx;
                minMaxLoc(result, &min_val, &max_val, &min_idx, &max_idx);
                if (max_val > max_val_thresh && max_val > rank_val) {
                    rank_val = max_val;
                    // rank = to_string(i + 1);
                    rank = i + 1;
                }
            }
        }
        output_rank = rank;
        output_rank_val = rank_val;
    }

    void match_suit(Mat image, vector<Mat> suit_images, uint32_t &output_suit, double &output_suit_val, double max_val_thresh=0.5) {
        double suit_val = 0.;
        // string suit = DEFAULT_SUIT;
        uint32_t suit = 0;
        for (size_t i = 0; i < NUM_SUITS; i++)
        {
            for (size_t j = 0; j < NUM_SUIT_TYPES; j++)
            {
                // string templ_name = assets_dir + "/suit_" + SUITS[i] + "_" + to_string(j) + ".JPG";
                // Mat templ = imread(templ_name, IMREAD_GRAYSCALE);
                Mat rgb_templ = suit_images[i*NUM_SUIT_TYPES+j];
                Mat templ;
                cvtColor(rgb_templ, templ, COLOR_BGR2GRAY);

                Mat result;
                matchTemplate(image, templ, result, TM_CCOEFF_NORMED);

                double min_val, max_val;
                Point min_idx, max_idx;
                minMaxLoc(result, &min_val, &max_val, &min_idx, &max_idx);
                if (max_val > max_val_thresh && max_val > suit_val) {
                    suit_val = max_val;
                    suit = i + 1;
                }
            }
        }
        output_suit = suit;
        output_suit_val = suit_val;
    }

    uint8_t* mat_to_bytes(Mat image) {
        int32_t size = image.total() * image.elemSize();
        uint8_t* bytes = new uint8_t[size];  // you will have to delete[] that later
        memcpy(bytes, image.data, size * sizeof(uint8_t));
        // vector<uint8_t> tmp;
        // imencode(".png", image, tmp);
        // int32_t size = tmp.size();
        // uint8_t* bytes = new uint8_t[size];
        // for (size_t i = 0; i < size; i++) {
        //     bytes[i] = tmp[i];
        // }
        return bytes;
    }

    struct Results
    {
        double* bboxes;
        uint32_t* ranks;
        uint32_t* suits;
        int64_t len;
    };
    

    FUNCTION_ATTRIBUTE
    struct Results process_image(
        int32_t input_len,
        int32_t height,
        int32_t width,
        uint8_t* image,
        int32_t* rank_heights,
        int32_t* rank_widths,
        uint8_t** rank_images,
        int32_t* suit_heights,
        int32_t* suit_widths,
        uint8_t** suit_images
    ) {
        // long long start = get_now();

        vector<Mat> rank_image_mats;
        for (size_t i = 0; i < 13; i++) {
            for (size_t j = 0; j < 2; j++) {
                int32_t height = rank_heights[i*2+j];
                int32_t width = rank_widths[i*2+j];
                rank_image_mats.push_back(Mat(height, width, CV_8UC3, rank_images[i*2+j]));
            }
        }
        vector<Mat> suit_image_mats;
        for (size_t i = 0; i < 4; i++) {
            for (size_t j = 0; j < 2; j++) {
                int32_t height = suit_heights[i*2+j];
                int32_t width = suit_widths[i*2+j];
                suit_image_mats.push_back(Mat(height, width, CV_8UC3, suit_images[i*2+j]));
            }
        }

        Mat input_image = Mat(height, width, CV_8UC3, image);

        // Mat image = imread(input_image_path, IMREAD_COLOR);
        // Mat gray = imread(input_image_path, IMREAD_GRAYSCALE);
        Mat gray;
        cvtColor(input_image, gray, COLOR_BGR2GRAY);

        Size s = input_image.size();
        int image_height = s.height;
        int image_width = s.width;

        Mat blur_image = gray.clone();
        blur(gray, blur_image, Size(5, 5), Point(-1, -1));

        Mat thresh_image = blur_image.clone();
        threshold(blur_image, thresh_image, 128, 255, THRESH_BINARY);

        vector<vector<Point>> contours;
        vector<Vec4i> hierarchy;
        findContours(thresh_image, contours, hierarchy, RETR_TREE, CHAIN_APPROX_NONE);
        sort(contours.begin(), contours.end(), compare_contour_areas);

        Mat canvas = input_image.clone();
        bool is_card_flags[contours.size()];
        vector<Mat> cards;

        // Outputs
        vector<vector<double>> point_dets;
        vector<uint32_t> rank_dets;
        vector<uint32_t> suit_dets;
        for (size_t i = 0; i < contours.size(); i++)
        {
            double size = contourArea(contours[i]);
            double peri = arcLength(contours[i], true);
            vector<Point> approx;
            approxPolyDP(contours[i], approx, 0.05 * peri, true);

            if ((size > (image_height * image_width / CARD_MIN_AREA))
                && (size < (image_height * image_width / CARD_MAX_AREA))
                && approx.size() == 4) {
                is_card_flags[i] = true;
                QueryCard card;
                preprocess_image(contours[i], input_image.clone(), card);

                // // draw contours
                // drawContours(canvas, contours, (int)i, Scalar(0, 255, 0), 6);

                uint32_t suit_top, suit_bottom, rank_top, rank_bottom;
                double suit_val_top, suit_val_bottom, rank_val_top, rank_val_bottom;

                match_suit(card.warped(Range(0, 150), Range(0, 70)), suit_image_mats, suit_top, suit_val_top);
                match_rank(card.warped(Range(0, 150), Range(0, 70)), rank_image_mats, rank_top, rank_val_top);

                Mat lb_card_image;
                flip(card.warped(Range(149, 299), Range(129, 199)), lb_card_image, -1);
                match_suit(lb_card_image, suit_image_mats, suit_bottom, suit_val_bottom);
                match_rank(lb_card_image, rank_image_mats, rank_bottom, rank_val_bottom);

                uint32_t suit;
                uint32_t rank;
                if (suit_val_top > suit_val_bottom) {
                    suit = suit_top;
                } else {
                    suit = suit_bottom;
                }

                if (rank_val_top > rank_val_bottom) {
                    rank = rank_top;
                } else {
                    rank = rank_bottom;
                }

                int x, y, w, h;
                x = card.box.x;
                y = card.box.y;
                w = card.box.width;
                h = card.box.height;

                // int baseline = y;
                // string text = to_string(rank) + to_string(suit);
                // Size text_size = getTextSize(text, FONT_HERSHEY_SIMPLEX, 4, 2, &baseline);
                // Rect text_rect(x, y-text_size.height-2, text_size.width, text_size.height);
                // rectangle(canvas, text_rect, Scalar(255, 255, 255), -1);
                // putText(canvas, text, Point(x, y), FONT_HERSHEY_SIMPLEX,
                //     4, Scalar(0, 140, 30), 2, LINE_AA);
                
                // Append to the outputs
                vector<double> bbox = {
                    static_cast<double>(x) / image_width,
                    static_cast<double>(y) / image_height,
                    static_cast<double>(x + w) / image_width,
                    static_cast<double>(y + h) / image_height
                };
                point_dets.push_back(bbox);
                rank_dets.push_back(rank);
                suit_dets.push_back(suit);
            }
        }
        
        // platform_log(image_output_path);
        int64_t len = rank_dets.size();
        struct Results results;
        results.len = len;
        if (len > 0) {
            results.bboxes = new double[4*len];

            int32_t index = 0;
            for (size_t i = 0; i < point_dets.size(); i++)
            {
                vector<double> p = point_dets[i];
                for (size_t j = 0; j < p.size(); j++)
                {
                    results.bboxes[index++] = p[j];
                }
            }
            results.ranks = &rank_dets[0];
            results.suits = &suit_dets[0];
        }

        // Mat outMat;
        // cvtColor(canvas, outMat, COLOR_BGR2BGRA);
        // imwrite("/tmp/temp.jpg", outMat);

        // int eval_in_ms = static_cast<int>(get_now() - start);
        // platform_log("Processing done in %dms\n", eval_in_ms);
        return results;
    }

    FUNCTION_ATTRIBUTE
    void free_mat(uint8_t* mat) {
        free(mat);
    }

    FUNCTION_ATTRIBUTE
    void free_struct(Results rs) {
        free(rs.bboxes);
        free(rs.ranks);
        free(rs.suits);
    }

    int clamp(int lower, int higher, int val){
        if(val < lower)
            return 0;
        else if(val > higher)
            return 255;
        else
            return val;
    }

    int getRotatedImageByteIndex(int x, int y, int rotatedImageWidth){
        return rotatedImageWidth*(y+1)-(x+1);
    }

    FUNCTION_ATTRIBUTE
    uint32_t *convert_yuv420_to_rgb(
        uint8_t *plane0,
        uint8_t *plane1,
        uint8_t *plane2,
        int bytesPerRow,
        int bytesPerPixel,
        int width,
        int height
    ){
        int hexFF = 255;
        int x, y, uvIndex, index;
        int yp, up, vp;
        int r, g, b;
        int rt, gt, bt;

        uint32_t *image = (uint32_t*)malloc(sizeof(uint32_t) * (width * height));

        for(x = 0; x < width; x++){
            for(y = 0; y < height; y++){
                
                uvIndex = bytesPerPixel * ((int) floor(x/2)) + bytesPerRow * ((int) floor(y/2));
                index = y*width+x;

                yp = plane0[index];
                up = plane1[uvIndex];
                vp = plane2[uvIndex];
            
                rt = round(yp + vp * 1436 / 1024 - 179);
                gt = round(yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91);
                bt = round(yp + up * 1814 / 1024 - 227);
                r = clamp(0, 255, rt);
                g = clamp(0, 255, gt);
                b = clamp(0, 255, bt);
            
                image[getRotatedImageByteIndex(y, x, height)] = (hexFF << 24) | (b << 16) | (g << 8) | r;
            }
        }
        return image;
    }

}