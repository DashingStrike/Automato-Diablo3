--

-- TODO: if bid failed in less than 100ms, do delay


dofile("shared.inc");

askText = singleLine([[
  Select window and press shift
]]);

local buy_enabled = true;
local check_all = false;
local buy_scale = 1.0;
local buy_price_override = -1; -- set to -1 to use normal prices, 0 to never buy
local assumption_time = 30000; -- 5000 was sometimes too short!

local max_delay;
local num_cycles;
if check_all then
	num_cycles = 2;
	max_delay = 1500;
else
	num_cycles = 2000;
	max_delay = 2500;
end

local buy_at = {
17,
83,
42,
26,
9,
32,
41,
25,
13,
18,
13,
15,
25,
23,
23,
15,
20,
32,
34,
18,
26,
41,
26,
27,
39,
116,
34,
39,
280,
1224,
126,
195,
27342,
28700,
26179,
26593,
127890,
137025,
117810,
126505,
453130,
465850,
388689,
439562,
1455572,
1525859,
1379700,
1413579,
4737319,
4838567,
4458766,
4465300,
15140678,
13855800,
15540000,
15225000,
1250000,
2500000,
425000,
550000,
750000,
1500000,
300000,
450000,
4250000,
7600000,
1700000,
3000000
};

local do_buy = {
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
2,
2,
2,
2,
2,
2,
2,
2,
2,
2,
2,
2
};

assert(#buy_at == 68);
assert(#do_buy == 68);

function waitForNewResults()
	local last_pixel_value = srReadPixelFromBuffer(watch_pos[0], watch_pos[1]);
	-- lsPrintln("last pixel value = " .. last_pixel_value);
	last_pixel_value = 268697855; -- Changes to 403770367 when fetching results
	saw_change = false;
	local state_change_time = lsGetTimer();

	-- Wait for results
	while true do
		local new_value = srReadPixel(watch_pos[0], watch_pos[1]);
		-- lsPrintln("new pixel value = " .. new_value);
		if not (new_value == last_pixel_value) then
			saw_change = true;
		end
		if (saw_change) then
			srReadScreen();
		end
		local buyout_pos = srFindImageInRange("AuctionBuyout.png", results_pos[0] + 210, results_pos[1] + 79, 80, 20);
		if not buyout_pos then
			buyout_pos = srFindImageInRange("AuctionBuyoutDisabled.png", results_pos[0] + 210, results_pos[1] + 79, 80, 20);
		end
		if buyout_pos then
			local have_results = false;
			if saw_change then
				have_results = true;
				printLn("Have results");
			else
				if lsGetTimer() > state_change_time + assumption_time then
					have_results = true;
					printLn("Time expired, assuming have results");
					lsPrintln("Time expired, assuming have results");
					srReadScreen(); -- read the screen, it hasn't been scraped yet
				end
			end
			if have_results then
				break;
			end
		else
			printLn("Unable to find 'Buyout'");
		end
		status("Waiting for results...");
	end
end

function getPriceQuote()
	if not findAndClick("AuctionSearch.png") then
		srReadScreen();
		if not findAndClick("AuctionSearch.png") then
			error "Unable to find AuctionSearch";
		end
	end
	waitForNewResults();

	while true do
		local buyout_pos = srFindImageInRange("AuctionBuyout.png", results_pos[0] + 210, results_pos[1] + 79, 80, 20);
		if not buyout_pos then
			buyout_pos = srFindImageInRange("AuctionBuyoutDisabled.png", results_pos[0] + 210, results_pos[1] + 79, 80, 20);
		end
		if not buyout_pos then
			printLn("Unable to find 'Buyout'");
		else
			local last_10_pos = srFindImageInRange("Last10Trades.png", results_pos[0] - 205, results_pos[1] + 170, 100, 30);
			if not last_10_pos then
				printLn("Unable to find 'Last 10 Trades'");
			else 
				-- get price and historical price
				local last_10_price = ocrNumber(last_10_pos[0]+84, last_10_pos[1], "7x9_", 7);
				if not last_10_price then
					printLn("Unable to parse Last 10 Trades Price");
				else 
					printLn("Last 10 Trades = " .. last_10_price);
				end
				local ppu = ocrNumber(buyout_pos[0] - 250, buyout_pos[1], "7x9_", 7);
				if not ppu then
					printLn("Unable to parse price per unit");
				else
					printLn("Price = " .. ppu);
				end
				if ppu and last_10_price then
					return ppu, last_10_price;
				end
			end
		end
		status("Determining price...");
		srReadScreen();
	end
end

local pre_buy_img_count = 0;

function saveScreen()
	srSaveLastReadScreen("pre_buy_" .. pre_buy_img_count .. ".png");
	pre_buy_img_count = pre_buy_img_count + 1;
end

function confirmBuy(max_price)
	while true do
		srReadScreen();
		local pos = srFindImage("AuctionBuyout2.png");
		if pos then
			-- TODO: confirm price!
			saveScreen();
			srClickMouseNoMove(pos[0], pos[1]);
			return;
		else
			local pos = srFindImage("AuctionInsufficient.png");
			if pos then
				lsPlaySound("InterventionRequired.wav");
				error "Out of money";
			else
				printLn("Clicked buy, response not found");
			end
		end
		status("Waiting to confirm buy...");
	end
end

function checkResults()
	while true do
		srReadScreen();
		local pos = srFindImage("AuctionBuyoutAccepted.png");
		if pos then
			-- success!
			lsPlaySound("Clank.wav");
			-- click OK
			srClickMouseNoMove(pos[0], pos[1] + 86);
			lsSleep(80);
			-- num_purchases = num_purchases + 1;
			-- if num_purchases == desired_batches then
			--	lsPlaySound("Complete.wav");
			--	error "All purchases completed";
			-- end
			return true;
		else
			pos = srFindImage("AuctionBidFailed.png");
			if not pos then
				pos = srFindImage("YourTransaction.png");
			end
			if pos then
				printLn("Bid failed");
				-- click OK
				srClickMouseNoMove(pos[0], pos[1] + 86);
				return false;
			else
				pos = srFindImage("AuctionBidTimedOut.png");
				if pos then
					printLn("Bid timed out");
					-- click OK
					srClickMouseNoMove(pos[0], pos[1] + 86);
					return false;
				else
					printLn("Waiting for bid to complete...");
				end
			end
		end
		status("Waiting for results...");
	end
end

function doBuy(max_price)
	local buyout_pos = srFindImageInRange("AuctionBuyout.png", results_pos[0] + 210, results_pos[1] + 79, 80, 20);
	if not buyout_pos then
		lsPlaySound("InterventionRequired.wav");
		lsSleep(1000);
	else
		srClickMouseNoMove(buyout_pos[0], buyout_pos[1]);
		confirmBuy(max_price);
		return checkResults();
	end
end


function doit()
	local mousePos = askForWindow(askText);

	local color = 0xFFFFFFff;
	local state = "select_quality";
	local gem_quality;
	local gem_type;
	local saw_change;
	local num_purchases = 0;
	sharedInit();

	local data = {};
	for gem_quality=0, 13+3 do
		data[gem_quality] = {};
	end

	local i = 0;
	local last_ppu = 0;
	local last_last_10 = 0;
	for i=0, num_cycles do
		local report = '"quality","type","min","max","avg","last 10"\n';
		local idx = 0;
		for gem_quality=0, 13+3 do
			for gem_type=0, 3 do
				idx = idx + 1;
				local this_do_buy = do_buy[idx];
				if not this_do_buy then
					this_do_buy = 0;
				end
				if (buy_enabled and this_do_buy == 0 and not check_all) then
					-- don't do this step
				else
					local title = i .. ": quality " .. gem_quality .. ", color " .. gem_type
					status(title .. "...");
					if gem_quality > 13 then
						selectPages();
						selectJewelerDesigns();
						selectQuality(gem_quality - 14 + 1);
						selectType(gem_type + 1);
						-- Select first/only plan in list
						srClickMouseNoMove(160, 577);
					else 
						selectGems();
						--selectQuantity(10);
						selectQuality(gem_quality);
						selectType(gem_type);
					end
					lsSleep(100);
					local ppu, last_10_price = getPriceQuote();
					if ppu == last_ppu and last_10_price == last_last_10 and last_10_price > 2000 then
						saveScreen();
						error "repeated PPU";
					end
					last_ppu, last_last_10 = ppu, last_10_price;
					local this_buy_at = buy_at[idx];
					if not (buy_price_override == -1) then
						this_buy_at = buy_price_override;
					end
					if not this_buy_at then
						this_buy_at = 0;
					end
					lsPrintln(gem_quality .. "  " .. gem_type .. ": " .. ppu);
					lsPrintln("Would buy at " .. this_buy_at);
					if (buy_enabled) and (ppu > 0) then
						while (ppu < this_buy_at * buy_scale and not (this_do_buy == 0)) do
							lsPrintln("Buying...");
							if doBuy(this_buy_at * buy_scale) then
								lsPrintln("Bought...");
								do_buy[idx] = do_buy[idx] - 1;
								this_do_buy = do_buy[idx];
							end
							ppu = getPriceQuote();
						end
					end
					title = title .. "\n  ppu: " .. ppu .. " l10: " .. last_10_price .. " buy_at: " .. this_buy_at .. " #:" .. this_do_buy;
					local s;
					if not data[gem_quality][gem_type] then
						data[gem_quality][gem_type] = {
							min = ppu,
							max = ppu,
							sum = ppu,
							last_10 = last_10_price,
							cnt = 1,
							values = {ppu}
						};
					else
						s = data[gem_quality][gem_type];
						s.min = math.min(s.min, ppu);
						s.max = math.max(s.max, ppu);
						s.sum = s.sum + ppu;
						s.cnt = s.cnt + 1;
						if i < 50 then
							s.values[#s.values + 1] = ppu;
						end
					end
					s = data[gem_quality][gem_type];
					report = report .. gem_quality .. "," .. gem_type .. "," ..
						s.min .. "," .. s.max .. "," .. math.floor(s.sum / s.cnt) .. "," ..
						s.last_10

					local j;
					table.sort(s.values);
					for j=1, #s.values do
						report = report .. "," .. s.values[j];
					end
					report = report .. "\n"
					local delay = 100 + math.random(max_delay);
					sleepWithStatus(delay, title .. ", Waiting before next query", 0xFFFFFFff, true);
				end
			end
		end
		i = i + 1;

		local filename = "gem_results_" .. (i % 2) .. ".txt";
		local f = io.open(filename,"w");
		f:write(report);
		f:close();
		lsPrintln("Wrote results to " .. filename);
	end

end
