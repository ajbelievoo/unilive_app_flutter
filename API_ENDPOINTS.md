# Unilive Application API Endpoints

Generated: 2026-07-13T09:05:11.433Z

## Backend Services

- **Main Backend**: https://admin.unilive.me/ (ports 5020-5023, scaled 4 instances)
- **Teenpatti Game**: https://teenpatti.unilive.me/ (port 5001)
- **Ferrywheel Game**: https://ferrywheel.unilive.me/ (port 5002)
- **Casino Game**: https://casino.unilive.me/ (port 5003)

## Total HTTP Endpoints: 572

### /activity

| Method | Path |
|--------|------|
| GET | /activity/ |
| POST | /activity/ |
| DELETE | /activity/:id |
| PATCH | /activity/:id |
| GET | /activity/userList |

### /admin

| Method | Path |
|--------|------|
| PATCH | /admin/ |
| POST | /admin/ |
| PUT | /admin/ |
| DELETE | /admin/deleteSubAdmin |
| GET | /admin/getSubAdmin |
| POST | /admin/login |
| GET | /admin/profile |
| POST | /admin/roleAssignement |
| POST | /admin/sendEmail |
| POST | /admin/setPassword/:adminId |
| PATCH | /admin/updateImage |
| PATCH | /admin/updateSubAdmin |
| GET | /admin/vip-config |
| PUT | /admin/vip-config |
| GET | /admin/vip-tiers/ |
| POST | /admin/vip-tiers/ |
| DELETE | /admin/vip-tiers/:id |
| PUT | /admin/vip-tiers/:id |
| POST | /admin/vip-tiers/upload-asset |
| GET | /admin/vip-users |
| DELETE | /admin/vip-users/:userId |
| PATCH | /admin/vip-users/:userId/toggle |

### /advertisement

| Method | Path |
|--------|------|
| GET | /advertisement/ |
| PATCH | /advertisement/:adId |
| PUT | /advertisement/:adId |

### /agency

| Method | Path |
|--------|------|
| PATCH | /agency/activeOrNot |
| GET | /agency/agencyWiseHost |
| GET | /agency/agencyWiseHostHistory |
| PATCH | /agency/connectAgencyToUser |
| POST | /agency/createAgencyByAdmin |
| POST | /agency/createHost |
| PATCH | /agency/deleteAgency |
| GET | /agency/getAgency |
| GET | /agency/getAgencyProfile |
| GET | /agency/getUnverifiedAgency |
| GET | /agency/getUserRedeem |
| GET | /agency/index |
| PATCH | /agency/isValid |
| POST | /agency/login |
| PATCH | /agency/shiftBd |
| POST | /agency/store |
| PATCH | /agency/superAdmin/shiftBd |
| PATCH | /agency/update |

### /agencySettlement

| Method | Path |
|--------|------|
| PATCH | /agencySettlement/actionInSettlement/:id |
| GET | /agencySettlement/agencySettlementForAgency |
| GET | /agencySettlement/getAllAgencyInfo |
| GET | /agencySettlement/getAllAgencySettlemtforPayOuts |
| GET | /agencySettlement/getAllSettlement |
| GET | /agencySettlement/pendingOrSolved |
| PUT | /agencySettlement/updatePaidHistroy/:id |

### /annoucement

| Method | Path |
|--------|------|
| GET | /annoucement/ |
| POST | /annoucement/all |

### /api

| Method | Path |
|--------|------|
| PATCH | /api/ |
| POST | /api/ |
| PUT | /api/ |
| PATCH | /api/admin/ |
| POST | /api/admin/ |
| PUT | /api/admin/ |
| DELETE | /api/admin/deleteSubAdmin |
| GET | /api/admin/getSubAdmin |
| POST | /api/admin/login |
| GET | /api/admin/profile |
| POST | /api/admin/roleAssignement |
| POST | /api/admin/sendEmail |
| POST | /api/admin/setPassword/:adminId |
| PATCH | /api/admin/updateImage |
| PATCH | /api/admin/updateSubAdmin |
| GET | /api/admin/vip-config |
| PUT | /api/admin/vip-config |
| GET | /api/admin/vip-tiers/ |
| POST | /api/admin/vip-tiers/ |
| DELETE | /api/admin/vip-tiers/:id |
| PUT | /api/admin/vip-tiers/:id |
| POST | /api/admin/vip-tiers/upload-asset |
| GET | /api/admin/vip-users |
| DELETE | /api/admin/vip-users/:userId |
| PATCH | /api/admin/vip-users/:userId/toggle |
| POST | /api/audio-mixer/:id/volume |
| POST | /api/audio-mixer/init |
| DELETE | /api/deleteSubAdmin |
| GET | /api/getSubAdmin |
| POST | /api/login |
| GET | /api/profile |
| POST | /api/roleAssignement |
| POST | /api/sendEmail |
| POST | /api/setPassword/:adminId |
| PATCH | /api/updateImage |
| PATCH | /api/updateSubAdmin |
| POST | /api/user/updateProfileBackground |
| GET | /api/user/vip-dice-skins |
| GET | /api/user/vip-points-history |
| GET | /api/user/vip-purchase-records |
| GET | /api/user/vip-status |
| GET | /api/user/vip-themes |
| GET | /api/user/vip-tiers |
| POST | /api/user/vip-tiers/buy |
| GET | /api/user/visitor-records |
| GET | /api/vip-config |
| PUT | /api/vip-config |
| GET | /api/vip-tiers/ |
| POST | /api/vip-tiers/ |
| DELETE | /api/vip-tiers/:id |
| PUT | /api/vip-tiers/:id |
| POST | /api/vip-tiers/upload-asset |
| GET | /api/vip-users |
| DELETE | /api/vip-users/:userId |
| PATCH | /api/vip-users/:userId/toggle |
| GET | /api/vip/rules |

### /appTesting

| Method | Path |
|--------|------|
| POST | /appTesting/ |
| GET | /appTesting/retriveTestingHistory |

### /audio-mixer

| Method | Path |
|--------|------|
| POST | /audio-mixer/:id/volume |
| POST | /audio-mixer/init |

### /banner

| Method | Path |
|--------|------|
| GET | /banner/ |
| POST | /banner/ |
| DELETE | /banner/:bannerId |
| PATCH | /banner/:bannerId |
| GET | /banner/all |

### /bd

| Method | Path |
|--------|------|
| PATCH | /bd/activeOrNot |
| GET | /bd/bdWiseAgency |
| GET | /bd/bdWiseAgencyTypeWise |
| POST | /bd/createBd |
| POST | /bd/createCoinSellerFromBd |
| GET | /bd/getBdForAgency |
| GET | /bd/getBdHosts |
| GET | /bd/getbdProfile |
| GET | /bd/index |
| PATCH | /bd/shiftSuperAdmin |
| POST | /bd/store |
| PATCH | /bd/update |
| PATCH | /bd/verifyBd |

### /bdSettlement

| Method | Path |
|--------|------|
| GET | /bdSettlement/getAllSettlement |
| GET | /bdSettlement/getBdSettlement |
| PATCH | /bdSettlement/payBdSettlement |

### /block

| Method | Path |
|--------|------|
| POST | /block/blockOrUnblockUser |
| GET | /block/getBlockedUsers |
| GET | /block/whoBlockUserList |

### /broadcastBanner

| Method | Path |
|--------|------|
| DELETE | /broadcastBanner/ |
| GET | /broadcastBanner/ |
| POST | /broadcastBanner/ |

### /chat

| Method | Path |
|--------|------|
| DELETE | /chat/clearChat |
| DELETE | /chat/deleteMessage |
| GET | /chat/getOldChat |
| POST | /chat/starMessage |
| POST | /chat/uploadImage |

### /chatTopic

| Method | Path |
|--------|------|
| GET | /chatTopic/chatList |
| POST | /chatTopic/createRoom |
| DELETE | /chatTopic/deleteAllChatsAndTopics |
| POST | /chatTopic/mute |

### /coinPlan

| Method | Path |
|--------|------|
| GET | /coinPlan/ |
| POST | /coinPlan/ |
| DELETE | /coinPlan/:planId |
| PATCH | /coinPlan/:planId |
| GET | /coinPlan/history |
| GET | /coinPlan/isTopToggle |
| POST | /coinPlan/purchase/googlePlay |
| POST | /coinPlan/purchase/stripe |
| POST | /coinPlan/stripe/createCustomer |

### /coinSeller

| Method | Path |
|--------|------|
| GET | /coinSeller/ |
| PATCH | /coinSeller/activeOrNot |
| PATCH | /coinSeller/coinByadmin |
| PATCH | /coinSeller/coinByCoinSeller |
| PATCH | /coinSeller/coinLessByAdmin |
| POST | /coinSeller/create |
| DELETE | /coinSeller/delete |
| PATCH | /coinSeller/editMobileNumber |
| GET | /coinSeller/getAll |
| GET | /coinSeller/getCoinSellerUser |
| PATCH | /coinSeller/isTopSeller |
| PATCH | /coinSeller/switchSuperseller |

### /coinSellerHistory

| Method | Path |
|--------|------|
| GET | /coinSellerHistory/getCoinSellerHistory |
| GET | /coinSellerHistory/historyOfCoinSellerToUser |

### /comment

| Method | Path |
|--------|------|
| DELETE | /comment/ |
| GET | /comment/ |
| POST | /comment/ |

### /commission

| Method | Path |
|--------|------|
| DELETE | /commission/delete |
| GET | /commission/get |
| POST | /commission/store |
| PATCH | /commission/update |

### /complain

| Method | Path |
|--------|------|
| GET | /complain/ |
| POST | /complain/ |
| PATCH | /complain/:complainId |
| GET | /complain/userList |

### /countryhead

| Method | Path |
|--------|------|
| POST | /countryhead/assignCoinByAdmin |
| POST | /countryhead/assignCoinToCoinSeller |
| PATCH | /countryhead/blockAgency |
| PATCH | /countryhead/blockBD |
| PATCH | /countryhead/blockHost |
| PATCH | /countryhead/blockSuperAdmin |
| POST | /countryhead/create |
| POST | /countryhead/createSuperAdmin |
| GET | /countryhead/getAgencyList |
| GET | /countryhead/getAll |
| GET | /countryhead/getBdList |
| GET | /countryhead/getCountryHeadCoinHistory |
| GET | /countryhead/getCountryHeadCoinHistoryForCountryHead |
| GET | /countryhead/getcountryHeadWisesuperAdminList |
| GET | /countryhead/getDashboardData |
| GET | /countryhead/getHostList |
| GET | /countryhead/getHostLiveHistory |
| GET | /countryhead/getHostRequests |
| GET | /countryhead/getProfile |
| GET | /countryhead/getSuperAdminList |
| GET | /countryhead/getUserByCountry |
| PATCH | /countryhead/hostRequestAcceptOrDecline |
| POST | /countryhead/login |
| PATCH | /countryhead/shiftAssignRegionManager |
| PATCH | /countryhead/update |
| PATCH | /countryhead/updatePassword |
| PATCH | /countryhead/updateProfile |
| PATCH | /countryhead/updateProfilePassword |
| PATCH | /countryhead/updateSuperAdmin |

### /dashboard

| Method | Path |
|--------|------|
| GET | /dashboard/ |
| GET | /dashboard/analytic |

### /fakeComment

| Method | Path |
|--------|------|
| GET | /fakeComment/ |
| POST | /fakeComment/ |
| DELETE | /fakeComment/:commentId |
| PATCH | /fakeComment/:commentId |
| GET | /fakeComment/index |

### /family

| Method | Path |
|--------|------|
| DELETE | /family/:familyId |
| GET | /family/:familyId |
| POST | /family/create |
| POST | /family/join |
| POST | /family/leave |
| GET | /family/list |
| GET | /family/members |
| GET | /family/rewards |
| POST | /family/transferLeadership |
| GET | /family/userFamily |

### /favorite

| Method | Path |
|--------|------|
| GET | /favorite/ |
| GET | /favorite/likeUnlike |

### /follower

| Method | Path |
|--------|------|
| POST | /follower/followerList |
| GET | /follower/followFollowing |
| POST | /follower/followingList |
| POST | /follower/followUnfollow |

### /gameAdminCoin

| Method | Path |
|--------|------|
| GET | /gameAdminCoin/reset |

### /getStreamingSummary

| Method | Path |
|--------|------|
| GET | /getStreamingSummary/ |

### /gift

| Method | Path |
|--------|------|
| POST | /gift/ |
| GET | /gift/:categoryId |
| DELETE | /gift/:giftId |
| PATCH | /gift/:giftId |
| GET | /gift/all |
| POST | /gift/svgaAdd |

### /giftCategory

| Method | Path |
|--------|------|
| GET | /giftCategory/ |
| POST | /giftCategory/ |
| DELETE | /giftCategory/:categoryId |
| PATCH | /giftCategory/:categoryId |
| PATCH | /giftCategory/updateSequence |

### /hashtag

| Method | Path |
|--------|------|
| GET | /hashtag/ |
| POST | /hashtag/ |
| DELETE | /hashtag/:hashtagId |
| PATCH | /hashtag/:hashtagId |

### /history

| Method | Path |
|--------|------|
| POST | /history/ |
| POST | /history/call |
| GET | /history/callHistory |
| POST | /history/convertRcoinToDiamond |
| GET | /history/diamondRcoinHistory |
| GET | /history/diamondRcoinTotal |
| GET | /history/ferryWheel |
| POST | /history/income/seeAd |
| POST | /history/live |
| POST | /history/liveAnalytic |
| GET | /history/rouletteCasino |
| GET | /history/sendGiftFakeHost |
| GET | /history/teenPatti |
| GET | /history/transactions |
| POST | /history/transactions/create |
| GET | /history/transactions/summary |

### /host

| Method | Path |
|--------|------|
| GET | /host/ |
| PATCH | /host/assignCoinSeller |
| GET | /host/callHistory |
| GET | /host/hostCallHistoryForAgency |
| GET | /host/hostCoinEarningForAgency |
| GET | /host/hostHistoryByDate |
| GET | /host/hostLiveHistoryForAgency |
| PATCH | /host/isBlock |
| GET | /host/levelData |
| GET | /host/liveStreaming |
| GET | /host/profile |
| PATCH | /host/removeHost |
| PATCH | /host/shiftAgency |
| PATCH | /host/superAdmin/shiftAgency |
| GET | /host/topCreators |

### /hostLevel

| Method | Path |
|--------|------|
| GET | /hostLevel/ |
| POST | /hostLevel/ |
| DELETE | /hostLevel/:levelId |
| PATCH | /hostLevel/:levelId |

### /hostLiveHistory

| Method | Path |
|--------|------|
| GET | /hostLiveHistory/ |
| GET | /hostLiveHistory/agecyHost |
| GET | /hostLiveHistory/bdHostHistory |
| GET | /hostLiveHistory/getAllAgenciesHostLiveHistory |
| GET | /hostLiveHistory/history |
| GET | /hostLiveHistory/host/liveHistory |
| GET | /hostLiveHistory/hostHistory |
| GET | /hostLiveHistory/hostLive |
| GET | /hostLiveHistory/hostLiveHistoryToday |
| GET | /hostLiveHistory/tempData |
| GET | /hostLiveHistory/todayEarning |

### /hostRequest

| Method | Path |
|--------|------|
| PATCH | /hostRequest/acceptOrDecline |
| PATCH | /hostRequest/addAgency |
| GET | /hostRequest/bdHostRequest |
| POST | /hostRequest/createRequest |
| POST | /hostRequest/directMakeHost |
| GET | /hostRequest/index |
| GET | /hostRequest/requestGetByAgency |

### /hostSettlement

| Method | Path |
|--------|------|
| PATCH | /hostSettlement/actionForHostSettlement/:id |
| GET | /hostSettlement/agencyWiseHostSettlement |
| GET | /hostSettlement/getPendingOrSolvedAll |
| GET | /hostSettlement/hostSettlementForHost |
| GET | /hostSettlement/pendingOrSolvedSettlement |
| PUT | /hostSettlement/updatePaidSettlement/:id |

### /level

| Method | Path |
|--------|------|
| GET | /level/ |
| PATCH | /level/ |
| POST | /level/ |
| DELETE | /level/:levelId |
| PATCH | /level/:levelId |
| PATCH | /level/updateCommentColor |

### /liveUser

| Method | Path |
|--------|------|
| GET | /liveUser/ |
| GET | /liveUser/checkLive |
| GET | /liveUser/checkLiveRoom |
| GET | /liveUser/fakeLiveUser |
| GET | /liveUser/fansRanking |
| GET | /liveUser/fetchAgencyReceivingRankings |
| GET | /liveUser/fetchHostReceivingRankings |
| GET | /liveUser/fetchUserSpendingRankings |
| GET | /liveUser/generateAgoraToken |
| GET | /liveUser/getLiveUserAdmin |
| GET | /liveUser/getLiveUserByAdmin |
| GET | /liveUser/getTime |
| PATCH | /liveUser/live |
| POST | /liveUser/liveStreamingCutByAdmin |
| PATCH | /liveUser/pinLiveUser |
| GET | /liveUser/random-pk-match |
| GET | /liveUser/retrieveRoomParticipantDetails |
| DELETE | /liveUser/terminateAudioSession |
| PATCH | /liveUser/updatePrivateCode |
| PATCH | /liveUser/updateRoomImage |

### /location

| Method | Path |
|--------|------|
| GET | /location/ |
| GET | /location/city |
| GET | /location/search |
| GET | /location/UKcity |

### /login

| Method | Path |
|--------|------|
| GET | /login |

### /luckyBanner

| Method | Path |
|--------|------|
| DELETE | /luckyBanner/ |
| GET | /luckyBanner/ |
| POST | /luckyBanner/ |

### /luckyId

| Method | Path |
|--------|------|
| DELETE | /luckyId/ |
| GET | /luckyId/ |
| PATCH | /luckyId/ |
| POST | /luckyId/ |
| POST | /luckyId/purchase |
| GET | /luckyId/user |

### /notification

| Method | Path |
|--------|------|
| POST | /notification/ |

### /pkGiftHistory

| Method | Path |
|--------|------|
| GET | /pkGiftHistory/ |

### /post

| Method | Path |
|--------|------|
| PATCH | /post/commentSwitch/:postId |
| DELETE | /post/deletePost |
| GET | /post/getFollowingPost |
| GET | /post/getPopularLatestPost |
| GET | /post/getPost |
| GET | /post/postById |
| PATCH | /post/updateFakePost |
| POST | /post/uploadFakePost |
| POST | /post/uploadPost |
| GET | /post/user |

### /reaction

| Method | Path |
|--------|------|
| POST | /reaction/add |
| DELETE | /reaction/delete |
| GET | /reaction/getReaction |
| PATCH | /reaction/update |

### /redeem

| Method | Path |
|--------|------|
| GET | /redeem/ |
| POST | /redeem/ |
| PATCH | /redeem/:redeemId |
| POST | /redeem/acceptAndDeclineReq |
| GET | /redeem/agencyRedeem |
| POST | /redeem/createAgencyRedeem |
| GET | /redeem/getRedeemsByCoinSeller |
| GET | /redeem/hostRedeem |
| GET | /redeem/user |

### /regionhead

| Method | Path |
|--------|------|
| POST | /regionhead/assignCoinByAdmin |
| POST | /regionhead/assignCoinToCountryHead |
| PATCH | /regionhead/assignCountryHeadtoSuperAdmin |
| PATCH | /regionhead/blockAgency |
| PATCH | /regionhead/blockBD |
| PATCH | /regionhead/blockCountryHead |
| PATCH | /regionhead/blockHost |
| PATCH | /regionhead/blockSuperAdmin |
| GET | /regionhead/countryHeadList |
| POST | /regionhead/create |
| POST | /regionhead/createContryHead |
| GET | /regionhead/getAgencyList |
| GET | /regionhead/getAll |
| GET | /regionhead/getBdList |
| GET | /regionhead/getDashboardData |
| GET | /regionhead/getHostList |
| GET | /regionhead/getHostLiveHistory |
| GET | /regionhead/getHostRequests |
| GET | /regionhead/getRegionHeadCoinHistory |
| GET | /regionhead/getRegionHeadCoinHistoryForRegionHead |
| GET | /regionhead/getRegionHeadWiseCountryHeadList |
| GET | /regionhead/getSuperAdminList |
| GET | /regionhead/getUserByCountry |
| PATCH | /regionhead/hostRequestAcceptOrDecline |
| POST | /regionhead/login |
| GET | /regionhead/profile |
| GET | /regionhead/regionHeadContryHeadList |
| PATCH | /regionhead/update |
| PATCH | /regionhead/updateAgency |
| PATCH | /regionhead/updateBd |
| PATCH | /regionhead/updateContryHead |
| PATCH | /regionhead/updateHost |
| PATCH | /regionhead/updatePassword |
| PATCH | /regionhead/updateProfile |
| PATCH | /regionhead/updateProfilePassword |
| PATCH | /regionhead/updateSuperAdmin |

### /report

| Method | Path |
|--------|------|
| GET | /report/ |
| POST | /report/ |

### /setting

| Method | Path |
|--------|------|
| GET | /setting/ |
| PATCH | /setting/:settingId |
| PUT | /setting/:settingId |
| PATCH | /setting/addGame/:settingId |
| DELETE | /setting/deleteGame/:settingId |
| DELETE | /setting/resetData |
| PATCH | /setting/updateGame/:settingId |
| POST | /setting/uploadApk |

### /song

| Method | Path |
|--------|------|
| GET | /song/ |
| POST | /song/ |
| DELETE | /song/:songId |
| PATCH | /song/:songId |

### /sticker

| Method | Path |
|--------|------|
| GET | /sticker/ |
| POST | /sticker/ |
| DELETE | /sticker/:stickerId |
| PATCH | /sticker/:stickerId |

### /superAdmin

| Method | Path |
|--------|------|
| GET | /superAdmin/adminbdList |
| GET | /superAdmin/adminStats |
| GET | /superAdmin/agencyList |
| PATCH | /superAdmin/assignSuperAdminToBd |
| GET | /superAdmin/bdList |
| PATCH | /superAdmin/blockAgency |
| PATCH | /superAdmin/blockBd |
| PATCH | /superAdmin/blockHost |
| POST | /superAdmin/create |
| POST | /superAdmin/createBd |
| GET | /superAdmin/getAgencyProfile |
| GET | /superAdmin/getAll |
| GET | /superAdmin/getAllHistory |
| GET | /superAdmin/getBdProfile |
| GET | /superAdmin/getDashboard |
| GET | /superAdmin/getHostProfile |
| GET | /superAdmin/getHostRequests |
| GET | /superAdmin/getUniqueId |
| GET | /superAdmin/hostList |
| PATCH | /superAdmin/hostRequestAcceptOrDecline |
| POST | /superAdmin/login |
| GET | /superAdmin/profile |
| PATCH | /superAdmin/shiftAssignOfficialManager |
| PATCH | /superAdmin/update |
| PATCH | /superAdmin/updateAgency |
| PATCH | /superAdmin/updateBd |
| PATCH | /superAdmin/updateHost |
| PATCH | /superAdmin/updatePassword |
| PATCH | /superAdmin/verifyAgency |

### /superSeller

| Method | Path |
|--------|------|
| GET | /superSeller/ |
| PATCH | /superSeller/ |
| POST | /superSeller/ |
| PATCH | /superSeller/assignCoin |
| POST | /superSeller/assignCoinToCountryHead |
| POST | /superSeller/assignCoinToRegionHead |
| PATCH | /superSeller/coinfromSuperSellerToSeller |
| PATCH | /superSeller/coinFromSuperSellerToUser |
| POST | /superSeller/createCoinSeller |
| GET | /superSeller/dashboard |
| GET | /superSeller/getCoinSeller |
| GET | /superSeller/getSellerHistory |
| GET | /superSeller/getSellerOfSuperSeller |
| GET | /superSeller/getSuperSellerHistory |
| GET | /superSeller/getSuperSellerHistoryForAdmin |
| PATCH | /superSeller/handleCoinSellerActive |
| PATCH | /superSeller/isActive |
| POST | /superSeller/login |
| GET | /superSeller/profile |
| PATCH | /superSeller/updatePassword |
| PATCH | /superSeller/updateProfile |

### /svga

| Method | Path |
|--------|------|
| DELETE | /svga/:Id |
| PATCH | /svga/:Id |
| GET | /svga/all |
| POST | /svga/assignFrameToUser |
| POST | /svga/create |
| POST | /svga/createFrame |
| POST | /svga/deselect |
| GET | /svga/get |
| POST | /svga/purchase |
| POST | /svga/select |
| POST | /svga/uploadSvgaFrames |

### /tags

| Method | Path |
|--------|------|
| DELETE | /tags/ |
| GET | /tags/ |
| PATCH | /tags/ |
| POST | /tags/ |
| PATCH | /tags/assignTagsToUser |

### /task

| Method | Path |
|--------|------|
| DELETE | /task/ |
| GET | /task/ |
| POST | /task/ |
| PATCH | /task/claimTaskReward |
| GET | /task/getTask |
| PATCH | /task/isActive |
| GET | /task/taskHistoryForAdmin |
| GET | /task/taskRewardHistory |

### /tempBlock

| Method | Path |
|--------|------|
| DELETE | /tempBlock/ |
| GET | /tempBlock/ |
| POST | /tempBlock/block-user |
| GET | /tempBlock/blockHistory |
| GET | /tempBlock/isUserBlocked |

### /theme

| Method | Path |
|--------|------|
| GET | /theme/ |
| POST | /theme/ |
| DELETE | /theme/:themeId |
| PATCH | /theme/:themeId |

### /user

| Method | Path |
|--------|------|
| POST | /user/AddFakeUser |
| POST | /user/addLessCoin |
| POST | /user/addReferralCode |
| GET | /user/admin/getUsers |
| PATCH | /user/assignVip |
| POST | /user/bindAccount |
| GET | /user/blockedUsers |
| PATCH | /user/blockUnblock/:userId |
| GET | /user/checkPlan |
| PUT | /user/gameBlock |
| GET | /user/getFakeData |
| GET | /user/getPopularUser |
| POST | /user/getUser |
| GET | /user/getUsers |
| GET | /user/getUsersUniqueId |
| GET | /user/getUsersUniqueIdForAgency |
| GET | /user/hostRating |
| POST | /user/likeUnlike |
| POST | /user/loginSignup |
| POST | /user/online |
| GET | /user/profile |
| GET | /user/random |
| POST | /user/rateHost |
| GET | /user/receivedGifts |
| PUT | /user/switchForEnableLiveUser |
| POST | /user/update |
| PATCH | /user/updateFakeUser |
| PATCH | /user/updateInvisible |
| PATCH | /user/updateLiveType |
| POST | /user/updateProfileBackground |
| POST | /user/updateUser |
| POST | /user/user/search |
| PATCH | /user/userUniqueId |
| GET | /user/visitors |
| POST | /user/visitProfile |

### /v3.1

| Method | Path |
|--------|------|
| GET | /v3.1/all |
| GET | /v3.1/alll |
| GET | /v3.1/allllll |

### /video

| Method | Path |
|--------|------|
| DELETE | /video/deleteRelite |
| GET | /video/getRelite |
| GET | /video/getReliteById |
| GET | /video/getVideo |
| PATCH | /video/relite/commentSwitch/:videoId |
| PATCH | /video/updateFakeRelite |
| POST | /video/uploadFakeRelite |
| POST | /video/uploadRelite |
| GET | /video/videoDetail |

### /vipPlan

| Method | Path |
|--------|------|
| GET | /vipPlan/ |
| POST | /vipPlan/ |
| DELETE | /vipPlan/:planId |
| PATCH | /vipPlan/:planId |
| PUT | /vipPlan/:planId |
| GET | /vipPlan/admin/history |
| GET | /vipPlan/history |
| GET | /vipPlan/isTopToggle |

## Main Backend Socket.IO Events

Connection URL: wss://admin.unilive.me/ (or https://admin.unilive.me/ with Socket.IO)

### Incoming Events (App -> Server): 72

| Event |
|-------|
| acceptJoinRequest |
| addParticipants |
| addParticipantsOfcalljoin |
| addRequested |
| addRequestedOfcalljoin |
| addView |
| allSeatLock |
| animatedFilter |
| audioLiveHostRemove |
| audioSpeaking |
| blockedList |
| blockedListFetched |
| callAnswer |
| callCancel |
| callConfirmed |
| callDisconnect |
| callReceive |
| callReceive |
| callRequest |
| cameraOffCallJoin |
| changeTheme |
| chat |
| checkUserStatus |
| comment |
| commentAudio |
| declineInvite |
| demoInfo |
| disconnect |
| ended |
| getUserProfile |
| getUserProfile2 |
| gif |
| highBit |
| joinRequest |
| lessParticipants |
| lessParticipantsOfcalljoin |
| lessRequestedOfcalljoin |
| lessView |
| liveHostEnd |
| liveRejoin |
| liveRoomConnect |
| liveStreaming |
| liveUserGift |
| lockSeat |
| manualDisconnect |
| messageRead |
| messageReadStatus |
| muteInCallJoin |
| muteSeat |
| normalUserGift |
| pkAnswer |
| pkEnd |
| pkPunishmentRound |
| pkRematch |
| pkRequest |
| pkScoreUpdate |
| rejectJoinRequest |
| reJoin |
| roomImageMessage |
| roomName |
| seatUpdate |
| sendReaction |
| simpleFilter |
| singleLiveUser |
| speaking |
| typing |
| typingStop |
| updateBlockedList |
| updateRoomAdmins |
| userCoinUpdate |
| userOffline |
| userOnline |

### Outgoing Events (Server -> App): 136

| Event |
|-------|
| acceptJoinRequest |
| acceptJoinRequest |
| addUser |
| allRemove |
| animatedFilter |
| audioLiveHostRemove |
| blockedList |
| blockedListUpdated |
| callAnswer |
| callCancel |
| callConfirmed |
| callReceive |
| callReceive |
| callReceive |
| callReceive |
| callReceive |
| callRequest |
| changeTheme |
| chat |
| chat |
| chat |
| chat |
| comment |
| comment |
| comment |
| demoInfo |
| dummy |
| dummy |
| ended |
| error |
| error |
| error |
| gif |
| gift |
| gift |
| gift |
| highBit |
| highValueGiftReceive |
| hostDetailsForAudience |
| invite |
| invite |
| isLiveUser |
| joinRequest |
| lessParticipants |
| lessParticipants |
| lessParticipants |
| liveEnd |
| liveEnd |
| liveHostEnd |
| liveRoomConnect |
| liveStreaming |
| luckyGift |
| messageStatus |
| messageStatus |
| messageStatus |
| messageStatus |
| messageStatus |
| muteSeat |
| muteSeatRejected |
| onAudioSpeaking |
| participants |
| participants |
| participants |
| participants |
| participants |
| pkAnswer |
| pkAnswer |
| pkAnswer |
| pkAnswer |
| pkAnswer |
| pkAnswer |
| pkAnswer |
| pkAnswer |
| pkAnswer |
| pkEnd |
| pkEnd |
| pkPunishmentRound |
| pkPunishmentRound |
| pkPunishmentRound |
| pkPunishmentRound |
| pkRematch |
| pkRematch |
| pkRequest |
| pkScoreUpdate |
| pkScoreUpdate |
| pkStart |
| pkStart |
| pkStart |
| pkStart |
| requested |
| requested |
| requested |
| requested |
| requested |
| roomAdminListUpdated |
| roomImageMessage |
| roomImageMessageError |
| roomImageMessageRejected |
| roomName |
| seat |
| seat |
| seat |
| seat |
| seat |
| seat |
| seat |
| seat |
| seat |
| seat |
| seat |
| seat |
| seat |
| seat |
| seat |
| seat |
| seat |
| sendReaction |
| simpleFilter |
| time |
| typing |
| typingStop |
| updateBlockedList |
| updateBlockedList |
| updateBlockedListRejected |
| updateRoomAdmins |
| updateRoomAdmins |
| updateRoomAdmins |
| userCoinUpdate |
| userOffline |
| userOffline |
| userOnline |
| userOnline |
| view |
| view |
| view |
| winLuckyGift |

## Game Backend Socket.IO Events

### Teenpatti

| Direction | Event |
|-----------|-------|
| incoming | bit |
| incoming | disconnect |
| incoming | startGame |
| incoming | user |
| outgoing | betRejected |
| outgoing | bit |
| outgoing | block |
| outgoing | game |
| outgoing | game |
| outgoing | game |
| outgoing | game |
| outgoing | start |
| outgoing | start |
| outgoing | start |
| outgoing | start |
| outgoing | start |
| outgoing | time |
| outgoing | topUsers |

### Ferrywheel

| Direction | Event |
|-----------|-------|
| incoming | bit |
| incoming | disconnect |
| incoming | historyRecord |
| incoming | startGame |
| incoming | user |
| outgoing | bit |
| outgoing | game |
| outgoing | game |
| outgoing | game |
| outgoing | gameRound |
| outgoing | gameRound |
| outgoing | historyRecord |
| outgoing | lastHistories |
| outgoing | lastHistories |
| outgoing | randomWinnerNumber |
| outgoing | randomWinnerNumber |
| outgoing | start |
| outgoing | start |
| outgoing | start |
| outgoing | time |
| outgoing | todayProfit |
| outgoing | todayProfit |
| outgoing | user |
| outgoing | winnerUserArray |

### Casino

| Direction | Event |
|-----------|-------|
| incoming | bit |
| incoming | disconnect |
| incoming | historyRecord |
| incoming | startGame |
| incoming | user |
| outgoing | bit |
| outgoing | game |
| outgoing | game |
| outgoing | game |
| outgoing | gameNumberHistory |
| outgoing | gameNumberHistory |
| outgoing | historyRecord |
| outgoing | randomWinnerNumber |
| outgoing | start |
| outgoing | start |
| outgoing | start |
| outgoing | start |
| outgoing | time |

## Game Backend HTTP Endpoints

| Service | Method | Path |
|---------|--------|------|
| Teenpatti | GET | /gameHistory/get |
| Teenpatti | GET | /gameHistory/result |
| Ferrywheel | GET | /* (SPA catch-all) |
| Casino | GET | /* (SPA catch-all) |

## Raw Data Files

- HTTP endpoints JSON: /tmp/unilive_routes_final.json
- Socket events JSON: /tmp/socket_events.json
