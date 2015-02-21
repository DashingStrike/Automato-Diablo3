--

dofile("shared.inc");

askText = singleLine([[
  Select window and press shift
]]);

local desired_quantity = 10;
local buy_price = 1000;
local desired_batches = 10;


function doit()
  local mousePos = askForWindow(askText);

  local state = "search";
  local last_pixel_value;
  local saw_change;
  local state_change_time = lsGetTimer();
  local num_purchases = 0;
  sharedInit();

  while 1 do
	srReadScreen();
    local color = 0xffffffff;
	local status = "";
	y = 50;

	printLn("State = " .. state);
	printLn("Num purchases = " .. num_purchases);

	local pos;

	function retry()
		state = "search";
		local delay = 100 + math.random(800);
		sleepWithStatus(delay, "Waiting to retry", color);
	end

	if state == "search" then
		local do_search = true;
		local q = findQuantity();
		if not q then
			--do_search = false;
		else
			--if not (q == desired_quantity) then
			--	printLn("Not desired quantity");
			--	do_search = false;
			--end
		end
		if do_search then
			if findAndClick("AuctionSearch.png") then
				state = "wait_for_result";
				last_pixel_value = srReadPixelFromBuffer(watch_pos[0], watch_pos[1]);
				saw_change = false;
				state_change_time = lsGetTimer();
			end
		end
	end

	if state == "wait_for_result" then
		local new_value = srReadPixelFromBuffer(watch_pos[0], watch_pos[1]);
		if not (new_value == last_pixel_value) then
			saw_change = true;
		end
		local buyout_pos = srFindImageInRange("AuctionBuyout.png", results_pos[0] + 210, results_pos[1] + 79, 80, 20);
		if buyout_pos then
			local have_results = false;
			if saw_change then
				have_results = true;
				printLn("Have results");
			else
				if lsGetTimer() > state_change_time + 5000 then
					have_results = true;
					printLn("Time expired, assuming have results");
				end
			end
			if have_results then
				state = "think_about_buying";
			end
		else
			printLn("Unable to find 'Buyout'");
		end
	end

	if state == "think_about_buying" then
		local buyout_pos = srFindImageInRange("AuctionBuyout.png", results_pos[0] + 210, results_pos[1] + 79, 80, 20);
		if not buyout_pos then
			printLn("Unable to find 'Buyout'");
		else 
			-- get price
			local ppu = ocrNumber(buyout_pos[0] - 250, buyout_pos[1], "7x9_", 7);
			lsPrintln("Price " .. ppu);
			if ppu then
				printLn("Price = " .. ppu);
				if ppu <= buy_price then
					srClickMouseNoMove(buyout_pos[0], buyout_pos[1]);
					state = "clicked_buy";
				else
					-- too expensive
					retry();
				end
			else
				printLn("Unable to parse price per unit");
			end
		end
	end

	if state == "clicked_buy" then
		-- confirm
		if findAndClick("AuctionBuyout2.png") then
			state = "buy_confirmed";
		else
			pos = srFindImage("AuctionInsufficient.png");
			if pos then
				lsPlaySound("InterventionRequired.wav");
				error "Out of money";
			else
				printLn("Clicked buy, response not found");
			end
		end
	end

	if state == "buy_confirmed" then
		pos = srFindImage("AuctionBuyoutAccepted.png");
		if pos then
			-- success!
			lsPlaySound("Clank.wav");
			-- click OK
			srClickMouseNoMove(pos[0], pos[1] + 86);
			-- Don't do retry() for long delay, try again quickly!
			lsSleep(80);
			state = "search";
			num_purchases = num_purchases + 1;
			if num_purchases == desired_batches then
				lsPlaySound("Complete.wav");
				error "All purchases completed";
			end
		else
			pos = srFindImage("AuctionBidFailed.png");
			if pos then
				printLn("Bid failed");
				-- click OK
				srClickMouseNoMove(pos[0], pos[1] + 86);
				retry();
			else
				printLn("Waiting for bid to complete...");
			end
		end
	end

	tick_delay = 0;
    statusScreen(status, color);
  end
end
