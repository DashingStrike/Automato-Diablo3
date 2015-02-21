dofile("common.inc");

local tol = 5000;
y = 0;
results_pos = {};
watch_pos = {};
local page = "gems";

function ocrNumber(x, y, prefix, charwidth)
	if not prefix then
		prefix = "";
		charwidth = 6
	end
	-- find first number
	local digit=nil;
	local offset=0;
	while (not digit) and (offset < 70) do
		for i=0, 9 do
			local pos = srFindImageInRange(prefix .. i .. ".png", x, y, 5, 9, tol);
			if pos then
				digit=i;
				break;
			end
		end
		if not digit then
			x = x+1;
			offset = offset + 1;
		end
	end
	if (offset > 0) then
		-- lsPrintln("Perf warning: OCR non-0 offset of " .. offset);
	end
	local ret = digit;
	while 1 do
		digit = nil;
		x = x + charwidth;
		offset = 0;
		while (not digit) and (offset < 5) do
			for i=0, 9 do
				local pos = srFindImageInRange(prefix.. i .. ".png", x, y, 5, 9, tol);
				if pos then
					digit=i;
					break;
				end
			end
			if not digit then
				-- skip commas
				x = x + 3;
				offset = offset + 3;
			end
		end
		if digit then
			ret = ret * 10 + digit;
		else
			break;
		end
	end
	return ret;
end

function printLn(msg)
    local color = 0xffffffff;
	lsPrint(10, y, 1, 1, 1, color, msg);
	y = y + 24;
end

function status(msg)
	y = 100;
	statusScreen(msg, 0xFFFFFFff, true);
end

function findQuantity()
	pos = srFindImage("AuctionQuantity.png");
	if (not pos) then
		printLn("Unable to find 'Quantity'");
	else
		if pos[1] < 420 then
			pos[1] = pos[1] + 23;
		else
			pos[1] = pos[1] + 25;
		end
		local q = ocrNumber(pos[0], pos[1]);
		if not q then
			printLn("Unable to parse quantity");
		else
			printLn("Quantity: " .. q);
			return q;
		end
	end
	return nil;
end

function findAndClick(img)
	local pos = srFindImage(img);
	if (not pos) then
		printLn("Search not available");
		return false;
	else
		srClickMouseNoMove(pos[0]+5, pos[1]+2);
		return true;
	end
end

function sharedInit()
	srReadScreen();
	results_pos = srFindImage("AuctionResults.png");
	if not results_pos then
		error "Unable to find 'Auction Results'";
	end
	watch_pos[0] = results_pos[0] + 185;
	watch_pos[1] = results_pos[1] + 74;
end

function selectDropdown(x, y, index)
	local pos;
	while true do
		pos = srFindImageInRange("SelectDown.png", x, y, 24, 24, tol);
		if pos then
			break;
		end
		printLn("Unable to find drop-down");
		status("Looking for drop-down");
		srReadScreen();
	end
	srClickMouseNoMove(pos[0]+2, pos[1]+2);
	lsSleep(0);
	-- find base
	pos[0] = pos[0] - 162;
	pos[1] = pos[1] + 43;
	-- add in offset
	pos[1] = pos[1] + math.floor(26.67 * index);
	srClickMouseNoMove(pos[0], pos[1]);
end

function selectQuality(quality)
	if page == "gems" then
		selectDropdown(335, 260, quality);
	else
		-- jeweler recipes
		selectDropdown(335, 260 + 130, quality);
	end
end

function selectType(type)
	selectDropdown(335, 326, type);
end

function selectJewelerDesigns()
	selectDropdown(335, 260, 1);
end


function selectCat(title, cat)
	local pos = srFindImageInRange(title, 165, 170, 220, 90);
	if pos then
		return;
	end
	pos = srFindImageInRange("Back.png", 136, 187, 36, 80);
	if pos then
		-- in a sub-page, go back
		local spot = getWaitSpot(147, 196);
		srClickMouseNoMove(pos[0], pos[1]);
		waitForChange(spot, 1000);
		srReadScreen();
	end
	pos = srFindImageInRange(cat, 140, 190, 170, 280);
	if not pos then
		error ("Unable to find " .. cat);
	end
	local spot = getWaitSpot(147, 196);
	srClickMouseNoMove(pos[0], pos[1]);
	waitForChange(spot, 1000);
	srReadScreen();
	pos = srFindImageInRange(title, 165, 190, 220, 20);
	if not pos then
		error ("Changing to " .. cat .. " failed");
	end
end

function selectGems()
	selectCat("TitleGems.png", "CatGems.png");
	page = "gems"
end

function selectPages()
	selectCat("TitlePages.png", "CatPages.png");
	page = "jeweler";
end

