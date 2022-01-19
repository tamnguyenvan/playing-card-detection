import cv2
import os
import numpy as np
import imutils
import time

# Width and height of card corner, where rank and suit are
CORNER_WIDTH = 32
CORNER_HEIGHT = 84

# Dimensions of rank train images
RANK_WIDTH = 70
RANK_HEIGHT = 73

# Dimensions of suit train images
SUIT_WIDTH = 70
SUIT_HEIGHT = 80

CARD_MIN_AREA = 30
CARD_MAX_AREA = 5

class Query_card:
	"""Structure to store information about query cards in the camera image."""

	def __init__(self):
		self.contour = [] # Contour of card
		self.width, self.height = 0, 0 # Width and height of card
		self.corner_pts = [] # Corner points of card
		self.center = [] # Center point of card
		self.warp = [] # 200x300, flattened, grayed, blurred image
		

def flattener(image, pts, w, h):
	"""Flattens an image of a card into a top-down 200x300 perspective.
	Returns the flattened, re-sized, grayed image."""
	temp_rect = np.zeros((4,2), dtype = "float32")
	
	s = np.sum(pts, axis = 2)

	tl = pts[np.argmin(s)]
	br = pts[np.argmax(s)]

	diff = np.diff(pts, axis = -1)
	tr = pts[np.argmin(diff)]
	bl = pts[np.argmax(diff)]

	# Need to create an array listing points in order of
	# [top left, top right, bottom right, bottom left]
	# before doing the perspective transform

	if w <= 0.8*h: # If card is vertically oriented
		temp_rect[0] = tl
		temp_rect[1] = tr
		temp_rect[2] = br
		temp_rect[3] = bl

	if w >= 1.2*h: # If card is horizontally oriented
		temp_rect[0] = bl
		temp_rect[1] = tl
		temp_rect[2] = tr
		temp_rect[3] = br

	# If the card is 'diamond' oriented, a different algorithm
	# has to be used to identify which point is top left, top right
	# bottom left, and bottom right.
	
	if w > 0.8*h and w < 1.2*h: #If card is diamond oriented
		# If furthest left point is higher than furthest right point,
		# card is tilted to the left.
		if pts[1][0][1] <= pts[3][0][1]:
			# If card is titled to the left, approxPolyDP returns points
			# in this order: top right, top left, bottom left, bottom right
			temp_rect[0] = pts[1][0] # Top left
			temp_rect[1] = pts[0][0] # Top right
			temp_rect[2] = pts[3][0] # Bottom right
			temp_rect[3] = pts[2][0] # Bottom left

		# If furthest left point is lower than furthest right point,
		# card is tilted to the right
		if pts[1][0][1] > pts[3][0][1]:
			# If card is titled to the right, approxPolyDP returns points
			# in this order: top left, bottom left, bottom right, top right
			temp_rect[0] = pts[0][0] # Top left
			temp_rect[1] = pts[3][0] # Top right
			temp_rect[2] = pts[2][0] # Bottom right
			temp_rect[3] = pts[1][0] # Bottom left
			
		
	maxWidth = 200
	maxHeight = 300

	# Create destination array, calculate perspective transform matrix,
	# and warp card image
	dst = np.array([[0,0],[maxWidth-1,0],[maxWidth-1,maxHeight-1],[0, maxHeight-1]], np.float32)
	M = cv2.getPerspectiveTransform(temp_rect,dst)
	warp = cv2.warpPerspective(image, M, (maxWidth, maxHeight))
	warp = cv2.cvtColor(warp,cv2.COLOR_BGR2GRAY)		
	(T, th) = cv2.threshold(warp, 0, 255, cv2.THRESH_BINARY_INV | cv2.THRESH_OTSU)

	return th

def preprocess_card(contour, image):
	"""Uses contour to find information about the query card. Isolates rank
	and suit images from the card."""

	# Initialize new Query_card object
	qCard = Query_card()

	qCard.contour = contour

	# Find perimeter of card and use it to approximate corner points
	peri = cv2.arcLength(contour,True)
	approx = cv2.approxPolyDP(contour,0.01*peri,True)
	pts = np.float32(approx)
	qCard.corner_pts = pts

	# Find width and height of card's bounding rectangle
	x,y,w,h = cv2.boundingRect(contour)
	qCard.width, qCard.height = w, h

	# Find center point of card by taking x and y average of the four corners.
	average = np.sum(pts, axis=0)/len(pts)
	cent_x = int(average[0][0])
	cent_y = int(average[0][1])
	qCard.center = [cent_x, cent_y]

	# Warp card into 200x300 flattened image using perspective transform
	qCard.warp = flattener(image, pts, w, h)
	# qCard.rank_img = qCard.warp[h-RANK_HEIGHT:h, w-RANK_WIDTH:w]
	# qCard.suit_img = qCard.warp[h-RANK_HEIGHT-SUIT_HEIGHT:h-RANK_HEIGHT, w-SUIT_WIDTH:w]
	qCard.warp = imutils.rotate(qCard.warp, 180)

	return qCard

def match_suit(img):
	folder = "./template/suit/"
	suits = ["c", "d", "h", "s"]

	suit = "Unknown"
	suit_Val = 0

	for s in suits:
		for i in range(0, 2):
			tmp_name = folder + s + "_{}.JPG".format(i)
			template = cv2.imread(tmp_name, 0)
			w, h = template.shape[::-1]
			res = cv2.matchTemplate(img,template,cv2.TM_CCOEFF_NORMED)
			maxVal = np.amax(res)
			if maxVal > 0.5 and maxVal > suit_Val:
				suit_Val = maxVal
				suit = s	

	return suit, suit_Val
	
def match_rank(img):
	folder = "./template/rank/"		

	rank = "Unknown"
	rank_Val = 0

	for i in range(1, 14):
		for j in range(0, 2):
			tmp_name = folder + "{}_{}.JPG".format(i, j)
			template = cv2.imread(tmp_name, 0)
			w, h = template.shape[::-1]
			res = cv2.matchTemplate(img,template,cv2.TM_CCOEFF_NORMED)
			maxVal = np.amax(res)
			if maxVal > 0.5 and maxVal > rank_Val:
				rank_Val = maxVal
				rank = i

	return rank, rank_Val



input_folder = "./five cards/"
output_folder = "./five cards_out/"

flag = 0
for entry in os.scandir(input_folder):
	# if flag == 1:
	# 	break

	# flag = 1
	if entry.is_file():
		start_time = time.time()
		col_img = cv2.imread(input_folder + entry.name, cv2.IMREAD_COLOR)
		ori_img = cv2.imread(input_folder + entry.name, cv2.IMREAD_GRAYSCALE)		

		print(entry.name)
		(image_h, image_w) = ori_img.shape[:2]

		img_blur = cv2.blur(ori_img, (5,5), 0)

		th, im_th = cv2.threshold(img_blur, 128, 255, cv2.THRESH_BINARY)

		contours, hierarchy = cv2.findContours(im_th, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
		index_sort = sorted(range(len(contours)), key=lambda i : cv2.contourArea(contours[i]), reverse=True)

		cnts_sort = []
		hier_sort = []
		cnt_is_card = np.zeros(len(contours),dtype=int)		

		for i in index_sort:
			cnts_sort.append(contours[i])
			hier_sort.append(hierarchy[0][i])

		k = 1

		for i in range(len(cnts_sort)):
			size = cv2.contourArea(cnts_sort[i])
			peri = cv2.arcLength(cnts_sort[i],True)
			approx = cv2.approxPolyDP(cnts_sort[i],0.05*peri,True)
			
			if size > (image_h * image_w // CARD_MIN_AREA) and size < (image_h * image_w // CARD_MAX_AREA) and len(approx) == 4:
			# if len(approx) == 4:				
				# print(len(approx))			
			# 	# draw in blue the contours that were founded
				cnt_is_card[i] = 1
				card = preprocess_card(cnts_sort[i], col_img)
				# cv2.imshow("card", card.warp[150:300, 130:200])				

				# cv2.waitKey()
				cv2.drawContours(col_img, cnts_sort[i], -1, (0, 255, 0), 3)								
				# cv2.imwrite(output_folder + entry.name + "card_{}.jpg".format(k), card.warp)		
				# cv2.imwrite(output_folder + entry.name + "card_{}_c.jpg".format(k), card.warp[75:150, 0:70])
				# cv2.imwrite(output_folder + entry.name + "card_{}_cc.jpg".format(k), card.warp[0:73, 0:70])

				suit1, suit_val1 = match_suit(card.warp[0:150, 0:70])
				rank1, rank_val1 = match_rank(card.warp[0:150, 0:70])

				left_bottom_card = imutils.rotate(card.warp[149:299, 129:199], 180)
				suit2, suit_val2 = match_suit(left_bottom_card)
				rank2, rank_val2 = match_rank(left_bottom_card)

				suit = ""
				rank = 0

				if suit_val1 > suit_val2:
					suit = suit1
				else:
					suit = suit2

				if rank_val1 > rank_val2:
					rank = rank1
				else:
					rank = rank2

				# print(suit+str(rank))

				x,y,w,h = cv2.boundingRect(cnts_sort[i])

				font = cv2.FONT_HERSHEY_SIMPLEX
				cv2.putText(col_img, suit+str(rank),(x,y),font,2,(0,0,255),2,cv2.LINE_AA)

				k = k + 1

		# cv2.imwrite(output_folder + entry.name, col_img)				
		# (w, h) = ori_img.shape[::-1]
		# imS = cv2.resize(col_img, (w//2, h//2)) 
		# cv2.imshow("color", imS)
		# cv2.waitKey()
		cv2.imwrite(output_folder + entry.name, col_img)		
		end_time = time.time()
		# print("The time of execution of above program is : {}s".format(end_time - start_time))



		

