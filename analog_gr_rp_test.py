# -*- coding: utf-8 -*-
import cv2
import numpy as np
import glob
import os
import sys
import random
import time
import json
import base64
import requests
from datetime import datetime, timedelta
import pytz
import shutil

def write_to_log_file(log_message):
    log_file_path = 'python_log.txt'

    # Open the log file in append mode
    with open(log_file_path, 'a') as log_file:
        # Write the message to the log file
        log_file.write(log_message + '\n')

def is_image_dark(image_name, brightness_threshold):
    # Load the image
    image = cv2.imread('images/%s' %(image_name))

    # Convert the image to grayscale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # Calculate the average brightness (luminance)
    average_brightness = cv2.mean(gray)[0]

    write_to_log_file("average_brightness = %s" % (average_brightness))
    write_to_log_file("brightness_threshold = %s" % (brightness_threshold))

    # Compare the average brightness to the threshold
    is_dark = average_brightness < brightness_threshold

    return average_brightness, is_dark

def is_within_brightness_range():
    # Get the current time in Singapore
    tz = pytz.timezone('Asia/Singapore')
    current_time_sg = datetime.now(tz)

    # Check if the current time is within the brightness range (7 PM to 6 AM)
    return current_time_sg.hour >= 19 or current_time_sg.hour < 6

def darken_needle(image_name, threshold_value):
    # Load the image
    image = cv2.imread('images/%s' %(image_name), cv2.IMREAD_GRAYSCALE)
    
    # Apply thresholding to make the needle darker
    _, thresholded_image = cv2.threshold(image, threshold_value, 255, cv2.THRESH_BINARY_INV)

    # Convert the thresholded image to BGR format
    thresholded_image = cv2.cvtColor(thresholded_image, cv2.COLOR_GRAY2BGR)

    return thresholded_image

def increase_brightness(image_name, alpha, beta):
    # Load the image
    image = cv2.imread('images/%s' %(image_name))

    # Apply brightness adjustment
    adjusted_image = cv2.addWeighted(image, alpha, image, 0, beta)
    return adjusted_image

def rotate_image_counterclockwise(image_name):
    # Load the image
    img = cv2.imread('images/%s' %(image_name))

    # Define the angle of rotation
    angle = 30

    # Get the dimensions of the image
    (h, w) = img.shape[:2]

    # Calculate the rotation matrix
    center = (w // 2, h // 2)
    M = cv2.getRotationMatrix2D(center, angle, 1.0)

    # Rotate the image counter-clockwise
    M = cv2.getRotationMatrix2D(center, -angle, 1.0)
    rotated_counter_clockwise = cv2.warpAffine(img, M, (w, h))

    # Display the original and rotated images
    cv2.imwrite('images/%s' %(image_name), rotated_counter_clockwise)
    cv2.waitKey(0)
    cv2.destroyAllWindows()

def rotate_image_clockwise(image_name):
    # Load the image
    img = cv2.imread('images/%s' %(image_name))

    # Define the angle of rotation
    angle = 30

    # Get the dimensions of the image
    (h, w) = img.shape[:2]

    # Calculate the rotation matrix
    center = (w // 2, h // 2)
    M = cv2.getRotationMatrix2D(center, angle, 1.0)

    # Rotate the image clockwise
    rotated_clockwise = cv2.warpAffine(img, M, (w, h))

    # Display the original and rotated images
    cv2.imwrite('images/%s' %(image_name), rotated_clockwise)
    cv2.waitKey(0)
    cv2.destroyAllWindows()

def crop_image_using_circle(image_name):
    # Load the image
    img = cv2.imread('images/%s' %(image_name))

    # Convert the image to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Apply Gaussian blur to reduce noise
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)

    # Apply Canny edge detection to detect edges
    edges = cv2.Canny(blurred, 50, 150)
    # Detect circles using the HoughCircles function

    #circles = cv2.HoughCircles(edges, cv2.HOUGH_GRADIENT, dp=1, minDist=500, param1=200, param2=50, minRadius=0, maxRadius=155)
    circles = cv2.HoughCircles(gray, cv2.HOUGH_GRADIENT, dp=1, minDist=200, param1=200, param2=100, minRadius=50, maxRadius=500)
    
    if circles is not None:
        write_to_log_file("Number of circles detected after crop: %s" % (len(circles[0])))
    else:
        write_to_log_file("No circles detected in the image after crop.")
    # If circles are found, draw them and crop the image
    if circles is not None:
        # Convert the (x, y) coordinates and radius of the circles to integers
        circles = circles.astype(int)
        # Draw the circles on the original image
        #for (x, y, r) in circles[0]:
        #    cv2.circle(img, (x, y), r, (0, 255, 0), 2)

        # Crop and save each circle
        for i in range(len(circles[0])):
            x, y, r = circles[0][i]
            cropped = img[y - r:y + r, x - r:x + r]
            cv2.imwrite('images/crop' + str(i + 1) + '.jpg', cropped)

        cv2.waitKey(0)
        cv2.destroyAllWindows()
        # Return the number of circles detected
        return len(circles[0])
    else:
        # If no circles are detected, return 0
        return 0


def get_user_input(image_name):
    #min_angle = input('Min angle (lowest possible angle of dial) - in degrees: ')  # the lowest possible angle
    #max_angle = input('Max angle (highest possible angle) - in degrees: ')  # highest possible angle
    #min_value = input('Min value: ')  # usually zero
    #max_value = input('Max value: ')  # maximum reading of the gauge

    min_angle =30 
    max_angle =330
    min_value = 0
    max_value = 230
    write_to_log_file("min_angle %s max_angle %s min_value %s max_value %s" % (min_angle, max_angle, min_value, max_value))
    return min_angle, max_angle, min_value, max_value

def avg_circles(circles, b):
    avg_x = 0
    avg_y = 0
    avg_r = 0
    for i in range(b):
        # optional - average for multiple circles (can happen when a gauge is at a slight angle)
        avg_x = avg_x + circles[0][i][0]
        avg_y = avg_y + circles[0][i][1]
        avg_r = avg_r + circles[0][i][2]
    avg_x = int(avg_x / (b))
    avg_y = int(avg_y / (b))
    avg_r = int(avg_r / (b))
    return avg_x, avg_y, avg_r


# x,y is the centre of circle, r is radius of circle
def draw_pts_and_text_in_img_to_show_deg(img, x, y, r, image_path, gauge_number, file_type):
    # Put Text in seperation of 10 degree, that means 36 points in 360 degree circle
    separation = 10.0  # in degrees
    interval = int(360 / separation)

    # set empty arrays, 2 is for getting the x and y points for each point
    start = np.zeros((interval, 2))
    end = np.zeros((interval, 2))
    p_text = np.zeros((interval, 2))

    # start[i][j] is the x and y coordinates for the starting point of point to show angle
    # Since start point is before the circumference of circle, put 0.9 * r
    # Eq for any point in x-axis x = a + r * cos@, where a, b is centre point of circle
    # Eq for any point in y-axis y = b + r * sin@, where a, b is centre point of circle
    for i in range(0, interval):
        for j in range(0, 2):
            if j % 2 == 0:
                start[i][j] = x + 0.9 * r * np.cos(separation * i * 3.14 / 180)  # point for lines
            else:
                start[i][j] = y + 0.9 * r * np.sin(separation * i * 3.14 / 180)

    # end[i][j] is the x and y coordinates for the end point of point to show angle
    # Since end point is at the circumference of circle, put r itself in eqn
    # Eq for any point in x-axis x = a + r * cos@, where a, b is centre point of circle
    # Eq for any point in y-axis y = b + r * sin@, where a, b is centre point of circle
    for i in range(0, interval):
        for j in range(0, 2):
            if j % 2 == 0:
                end[i][j] = x + r * np.cos(separation * i * 3.14 / 180)
            else:
                end[i][j] = y + r * np.sin(separation * i * 3.14 / 180)

    text_offset_x = 10
    text_offset_y = 5

    # point for text labels, i+9 rotates the labels by 90 degrees
    # 1.2 * r since text is written outside the circumference of circle
    for i in range(0, interval):
        for j in range(0, 2):
            if j % 2 == 0:
                p_text[i][j] = x - text_offset_x + 0.8 * r * np.cos((separation) * (i + 9) * 3.14 / 180)
            else:
                p_text[i][j] = y + text_offset_y + 0.8 * r * np.sin((separation) * (i + 9) * 3.14 / 180)

    # add the lines and labels to the image
    # cv2.line(image, start_point, end_point, color, thickness)
    # start_point: It is the starting coordinates of the line.
    #              The coordinates are represented as tuples of two values i.e. (X, Y).
    # end_point: It is the ending coordinates of the line.
    #            The coordinates are represented as tuples of two values i.e. (X, Y).
    # color: It is the color of the line to be drawn.
    #        For RGB, we pass a tuple. eg: (255, 0, 0) for blue color.
    # thickness: It is the thickness of the line in px.

    # cv2.putText(image, text, org, font, fontScale, color[, thickness[, lineType[, bottomLeftOrigin]]])
    # image: It is the image on which text is to be drawn.
    # text: Text string to be drawn.
    # org: It is the coordinates of the bottom-left corner of the text string in the image.
    #      The coordinates are represented as tuples of two values i.e. (X, Y).
    # font: It denotes the font type. Some of font types are FONT_HERSHEY_SIMPLEX, FONT_HERSHEY_PLAIN, , etc.
    # fontScale: Font scale factor that is multiplied by the font-specific base size.
    # color: It is the color of text string to be drawn. For BGR, we pass a tuple. eg: (255, 0, 0) for blue color.
    # thickness: It is the thickness of the line in px.
    # lineType: This is an optional parameter.It gives the type of the line to be used.
    # bottomLeftOrigin: This is an optional parameter.
    #                   When it is true, the image data origin is at the bottom-left corner.
    #                   Otherwise, it is at the top-left corner.
    for i in range(0, interval):
        cv2.line(img, (int(start[i][0]), int(start[i][1])), (int(end[i][0]), int(end[i][1])), (0, 255, 0), 2)
        cv2.putText(img, '%s' % (int(i * separation)), (int(p_text[i][0]), int(p_text[i][1])), cv2.FONT_HERSHEY_SIMPLEX,
                    0.3, (0, 0, 0), 1, cv2.LINE_AA)

    # Image after the lines and labels added to the image
    cv2.imwrite('images/output/gauge-%s-calibration.%s' % (gauge_number, file_type), img)

    return img;


def find_and_draw_circle(image_path, gauge_number, file_type):
    img = cv2.imread(image_path)
    output = img.copy()
    height, width = img.shape[:2]
    #print("height = ", height)
    #print("width = ", width)

    # Convert the image to gray scale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # detect circles
    # restricting the search from 35-48% of the possible radii gives fairly good results across different samples.
    # 1 - dp value, larger this value, smaller the accumulator array become
    # 20 - minDist between the center(x,y) of detected circles
    #      if minDist is too small, multiple circles maybe falsely detected
    #      if minDist is large some circles mayn't be detected
    # 100 - param1 Canny edge detection requires two parameters — minVal and maxVal.
    #       Param1 is the higher threshold of the two. The second one is set as Param1/2.
    # 50  - param2, this is the accumulator threshold for the candidate detected circles.
    #       By increasing this threshold value, we can ensure that only the best circles,
    #       corresponding to larger accumulator values, are returned.
    # int(height*0.35) minRadius: Minimum circle radius.
    # int(height*0.48) maxRadius: Maximum circle radius.

    circles = cv2.HoughCircles(gray, cv2.HOUGH_GRADIENT, 1, 100, np.array([]), 100, 50, int(height * 0.35),
                               int(height * 0.48))

    #circles = cv2.HoughCircles(gray, cv2.HOUGH_GRADIENT, dp=1, minDist=200, param1=200, param2=100, minRadius=50, maxRadius=500)
    #circles = cv2.HoughCircles(gray, cv2.HOUGH_GRADIENT, dp=1, minDist=200, param1=200, param2=100, int(height * 0.35), int(height * 0.48))

    if circles is not None:
        write_to_log_file("find_and_draw_circle Number of circles detected: %s" % (len(circles[0])))
    else:
        write_to_log_file("find_and_draw_circle No circles detected in the image.")


    # Draw circles that are detected.
    if circles is not None:
        #a, b, r = circles.shape
        #print("circles.shape a = %s b = %s r = %s" % (a, b, r))

        # if there are more circles detected, we need to find average to get more accurate a,b, and r
        det_circles = np.round(circles[0, :]).astype("int")
        no_of_circles = len(det_circles)

        # Convert the circle parameters a, b and r to integers.
        circles = np.uint16(np.around(circles))

        for pt in circles[0, :]:
            a, b, r = pt[0], pt[1], pt[2]
            #print("no_of_circles %s circles.shape x = %s y = %s radius = %s" % (no_of_circles, a, b, r))

            # Draw the circumference of the circle.
            # cv2.circle(image, center_coordinates, radius, color, thickness)
            # image: It is the image on which the circle is to be drawn.
            # center_coordinates: It is the center coordinates of the circle.
            #                     The coordinates are represented as tuples of two values i.e.
            #                     (X coordinate value, Y coordinate value).
            # radius: It is the radius of the circle.
            # color: It is the color of the borderline of a circle to be drawn.
            #        For BGR, we pass a tuple. eg: (255, 0, 0) for blue color.
            #        (0, 255, 0) - Green
            #        (0, 0, 255) - Red
            # thickness: It is the thickness of the circle border line in px.
            #            Thickness of -1 px will fill the circle shape by the specified color.
            cv2.circle(img, (a, b), r, (0, 255, 0), 2)

            # Draw a small circle (of radius 1) to show the center.
            cv2.circle(img, (a, b), 1, (0, 0, 255), 3)
            cv2.imwrite('images/output/gauge-%s-circles-detected.%s' % (gauge_number, file_type), img)

        return img, a, b, r


def find_angle_between_2_points(x, y, final_line_list):
    x1 = final_line_list[0][0]
    y1 = final_line_list[0][1]
    x2 = final_line_list[0][2]
    y2 = final_line_list[0][3]

    #print("x=%s y=%s x1=%s y1=%s x2=%s y2=%s" % (x, y, x1, y1, x2, y2))
    # Angle of a line given 2 points is @= arctan(y2-y1/x2-x1)
    # find the farthest point from the center to be what is used to determine the angle
    dist_pt_0 = dist_2_pts(x, y, x1, y1)
    dist_pt_1 = dist_2_pts(x, y, x2, y2)
    #print("dist_pt_0=%s dist_pt_1=%s" % (dist_pt_0, dist_pt_1))

    if (dist_pt_0 > dist_pt_1):
        x_angle = x1 - x
        y_angle = y - y1
    else:
        x_angle = x2 - x
        y_angle = y - y2

    # take the arc tan of y/x to find the angle based on x-axis
    res = np.arctan(np.divide(float(y_angle), float(x_angle)))
    # np.rad2deg(res) #coverts to degrees

    #print("xangle %s" % (x_angle))
    #print("y_angle %s" % (y_angle))
    #print("res %s" % (res))
    #print("degree %s" % (np.rad2deg(res)))

    # these were determined by trial and error
    res = np.rad2deg(res)
    if x_angle > 0 and y_angle > 0:  # in quadrant I
        final_angle = 270 - res
    if x_angle < 0 and y_angle > 0:  # in quadrant II
        final_angle = 90 - res # this should be - based on test result
    if x_angle < 0 and y_angle < 0:  # in quadrant III
        final_angle = 90 - res
    if x_angle > 0 and y_angle < 0:  # in quadrant IV
        final_angle = 270 + res

    return final_angle


def dist_2_pts(x1, y1, x2, y2):
    return np.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)


# remove all lines outside a given radius
def get_final_line(img, lines, x, y, r, image_path, gauge_number, file_type):
    final_line_list = []

    # diff1LowerBound and diff1UpperBound determine how close the line should be from the center
    diff1LowerBound = 0.05
    diff1UpperBound = 0.7

    # diff2LowerBound and diff2UpperBound determine how close the other point of the line should be to the outside of the gauge
    diff2LowerBound = 0.5
    diff2UpperBound = 1.0

    output = img.copy()

    write_to_log_file("Filtering lines based on diff1 < diff1UpperBound * r and diff1 > diff1LowerBound * r and")
    write_to_log_file("diff2 < diff2UpperBound * r and diff2 > diff2LowerBound * r")
    for i in range(0, len(lines)):
        for x1, y1, x2, y2 in lines[i]:
            diff1 = dist_2_pts(x, y, x1, y1)  # x, y is center of circle
            diff2 = dist_2_pts(x, y, x2, y2)  # x, y is center of circle

            #print("x1 %s y1 %s x2 %s y2 %s" %(x1, y1, x2, y2))
            #print("diff1 %s diff2 %s" %(diff1, diff2))
            #img = output.copy()
            #img1 = output.copy()
            #cv2.line(img, (x1, y1), (x2, y2), (0, 255, 0), 2)
            #cv2.imwrite('images/output/gauge-%s-final_line%s.%s' % (gauge_number, i, file_type), img)
           
            # set diff1 to be the smaller (closest to the center) of the two), makes the math easier
            if diff1 > diff2:
                temp = diff1
                diff1 = diff2
                diff2 = temp
            write_to_log_file("get_final_line diff1 = %s diff1UpperBound * r = %s diff1LowerBound * r = %s" % (diff1, diff1UpperBound * r, diff1LowerBound * r))
            write_to_log_file("get_final_line diff2 = %s diff2UpperBound * r = %s diff2LowerBound * r = %s" % (diff2, diff2UpperBound * r, diff2LowerBound * r))

            # check if line is within an acceptable range
            if ((diff1 < diff1UpperBound * r) and (diff1 > diff1LowerBound * r) and
                (diff2 < diff2UpperBound * r) and (diff2 > diff2LowerBound * r)):
                line_length = dist_2_pts(x1, y1, x2, y2)
                #img = output.copy()
                #img1 = output.copy()
                #cv2.line(img, (x, y), (x1, y1), (0, 255, 0), 2)
                #cv2.line(img1, (x, y), (x2, y2), (0, 255, 0), 2)
                #print("Found a acceptable line line_length: %s" % line_length)
                #cv2.imwrite('images/output/gauge-%s-final_line%s.%s' % (gauge_number, i, file_type), img)
                #cv2.imwrite('images/output/gauge-%s-final_line%s_1.%s' % (gauge_number, i, file_type), img1)
                #print("x1 %s y1 %s x2 %s y2 %s" % (x1, y1, x2, y2))
                #print("diff1 = %s < diff1UpperBound * r = %s" % (diff1, diff1UpperBound * r))
                #print("diff1 = %s > diff1LowerBound * r = %s" % (diff1, diff1LowerBound * r))
                #print("diff2 = %s < diff2UpperBound * r = %s" % (diff2, diff2UpperBound * r))
                #print("diff2 = %s > diff2LowerBound * r = %s" % (diff2, diff2LowerBound * r))
                # add to final list
                final_line_list.append([x1, y1, x2, y2])
    write_to_log_file("\n")
    # assumes the first line is the best one
    x1 = final_line_list[0][0]
    y1 = final_line_list[0][1]
    x2 = final_line_list[0][2]
    y2 = final_line_list[0][3]
    #print("x1 %s y1 %s x2 %s y2 %s" %(x1, y1, x2, y2))

    dist_pt_0 = dist_2_pts(x, y, x1, y1)
    dist_pt_1 = dist_2_pts(x, y, x2, y2)
    #print("dist_pt_0=%s dist_pt_1=%s" % (dist_pt_0, dist_pt_1))

    if (dist_pt_0 > dist_pt_1):
        cv2.line(img, (x, y), (x1, y1), (0, 255, 0), 2)
    else:
        cv2.line(img, (x, y), (x2, y2), (0, 255, 0), 2)

    # for testing purposes, show the line overlayed on the original image
    cv2.imwrite('images/output/gauge-%s-final_line.%s' % (gauge_number, file_type), img)

    return final_line_list

def get_all_lines(image_path, gauge_number, file_type, x, y, r):
    img = cv2.imread(image_path)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    threshold = 100
    # Apply Canny edge detection
    edges = cv2.Canny(gray, threshold, threshold * 2)

    cv2.imwrite('images/output/gauge-%s-dst.%s' % (gauge_number, file_type), edges)
    # Set the threshold values for Hough Line Transform
    rho = 3
    theta = np.pi / 180
    min_line_length = 20
    max_line_gap = 2

    # Perform Hough Line Transform
    lines = cv2.HoughLinesP(edges, rho=rho, theta=theta, threshold=threshold,
                            minLineLength=min_line_length, maxLineGap=max_line_gap)

    output = img.copy()

    filtered_lines = []

    write_to_log_file("Filtering lines based on r * 0.6 <= dist_pt_0 <= r * 0.9 and dist_pt_0 - dist_pt_1 >= 22 and r * 0.05 <= dist_pt_1 <= r * 0.7")
    for i in range(0, len(lines)):
        for x1, y1, x2, y2 in lines[i]:
            img = output.copy()
            dist_pt_0 = dist_2_pts(x, y, x1, y1)
            dist_pt_1 = dist_2_pts(x, y, x2, y2)
            write_to_log_file("get_all_lines dist_pt_0=%s dist_pt_1=%s radius %s name all_line%s.%s" % (dist_pt_0, dist_pt_1, r, i, file_type))
            cv2.line(img, (x1, y1), (x2, y2), (0, 255, 0), 2)
            cv2.imwrite('images/output/all_lines/gauge-%s-all_line%s.%s' % (gauge_number, i, file_type), img)
   
            # Filter lines based on conditions
            if ((r * 0.6) <= dist_pt_0 <= (r * 0.9) and ((dist_pt_0 - dist_pt_1) >= 22) and ((r * 0.05) <= dist_pt_1 <= (r * 0.7))):
                filtered_lines.append(lines[i])
                # Save the filtered line as an image
                cv2.imwrite('images/output/all_lines/gauge-%s-filtered_line%s.%s' % (gauge_number, i, file_type), img)

    write_to_log_file("\n")
    return filtered_lines

def get_all_lines1(image_path, gauge_number, file_type):
    img = cv2.imread(image_path)
    gray2 = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Set threshold and maxValue
    thresh = 175
    maxValue = 255

    # If f (x, y) < T
    #    then f (x, y) = 0
    # else
    #    f (x, y) = 255
    # where
    #       f (x, y) = Coordinate Pixel Value
    #       T = Threshold Value.
    # Syntax: cv2.threshold(source, thresholdValue, maxVal, thresholdingTechnique)
    # Parameters:
    # -> source: Input Image array (must be in Grayscale).
    # -> thresholdValue: Value of Threshold below and above which pixel values will change accordingly.
    # -> maxVal: Maximum value that can be assigned to a pixel.
    # -> thresholdingTechnique: The type of thresholding to be applied.

    # apply thresholding which helps for finding lines
    th, dst = cv2.threshold(gray2, thresh, maxValue, cv2.THRESH_BINARY_INV);
    cv2.imwrite('images/output/gauge-%s-dst.%s' % (gauge_number, file_type), dst)

    # find lines
    # r = xcos@ + ysin@
    # rho : The resolution of the parameter r in pixels. We use 3 pixel to detect more lines
    # theta: The resolution of the parameter θ in radians. We use 1 degree (CV_PI/180)
    # threshold: The minimum number of intersections to "*detect*" a line
    # srn and stn: Default parameters to zero. Check OpenCV reference for more info
    lines = cv2.HoughLinesP(image=dst, rho=3, theta=np.pi / 180, threshold=100, minLineLength=10, maxLineGap=0)


    #output = img.copy()
    # for testing purposes, show all found lines
    #for i in range(0, len(lines)):
    #    for x1, y1, x2, y2 in lines[i]:
    #        img = output.copy()
    #        cv2.line(img, (x1, y1), (x2, y2), (0, 255, 0), 2)
    #        print('For Index %s x1 %s y1 %s x2 %s y2 %s' % (i, x1, y1, x2, y2))
    #        cv2.imwrite('images/output/gauge-%s-lines-test%s.%s' % (gauge_number, i, file_type), img)

    return lines


def main():

    files = glob.glob('images/crop*')
    for f in files:
        os.remove(f)

    file_path = 'python_log.txt'
    # Remove the file if it exists
    if os.path.exists(file_path):
        os.remove(file_path)

    folder_path = 'images/output'
    # Remove the directory and its contents
    if os.path.exists(folder_path):
        shutil.rmtree(folder_path)

    # Create the folder if it doesn't exist
    if not os.path.exists(folder_path):
        os.makedirs(folder_path)

    folder_path = 'images/output/all_lines'
    # Create the folder if it doesn't exist
    if not os.path.exists(folder_path):
        os.makedirs(folder_path)

    num_images = 88  # Number of images (e.g., meter1.jpeg, meter2.jpeg, etc.)

    for i in range(1, num_images + 1):
        #i=1
        image_name = f"meter{i}.jpeg"  # Construct the image name
        image_path = f"rp_test_images/{image_name}"  # Construct the image path


        # Copy the image to "meter.jpeg"
        shutil.copy(image_path, "images/meter.jpeg")

        write_to_log_file("Starting Test meter%s.jpeg" % (i))
        write_to_log_file("==========================")

        # Perform the operations on the image
        num_circles = crop_image_using_circle("meter.jpeg")
        for j in range(1, num_circles + 1):
            image_name = f"crop{j}.jpg"  # Construct the cropped image name
            min_angle, max_angle, min_value, max_value = get_user_input(image_name)

            write_to_log_file("Starting Test crop%s.jpg" % (j))
            write_to_log_file("==========================")

            image_path = f"images/{image_name}"
            brightness_threshold = 150

            average_brightness, is_dark = is_image_dark(image_name, brightness_threshold)

            if is_dark:
                if average_brightness < 120:
                    brightened_image = increase_brightness(image_name, 1.8, 10)
                elif average_brightness < 140:
                    brightened_image = increase_brightness(image_name, 1.5, 10)
                else:
                    brightened_image = increase_brightness(image_name, 1.2, 10)
                cv2.imwrite(image_path, brightened_image)

            gauge_number = j
            file_type = 'jpg'
            files = glob.glob(f'images/output/gauge-{gauge_number}*')
            for f in files:
                os.remove(f)

            img, x, y, r = find_and_draw_circle(image_path, gauge_number, file_type)
            img = draw_pts_and_text_in_img_to_show_deg(img, x, y, r, image_path, gauge_number, file_type)
            lines = get_all_lines(image_path, gauge_number, file_type, x, y, r)
            no_of_lines = len(lines)
            # print("no_of_lines = %s" % (no_of_lines))
            final_line_list = get_final_line(img, lines, x, y, r, image_path, gauge_number, file_type)
            final_angle = find_angle_between_2_points(x, y, final_line_list)
            # print("final_angle %s" % (final_angle))

            angle_range = (float(max_angle) - float(min_angle))
            val_range = (float(max_value) - float(min_value))
            new_value = (((float(final_angle) - float(min_angle)) * val_range) / angle_range) + float(min_value)
            write_to_log_file("Current reading: For Image meter%s.jpeg %s PSI" % (i, new_value))
            print(f"Current reading: For Image meter{i}.jpeg {new_value} PSI")

if __name__ == '__main__':
    main()
