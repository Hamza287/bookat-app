class AppStrings {
  const AppStrings._();

  static const appName = 'Bookat';

  static const notificationsTooltip = 'Notifications';
  static const menuTooltip = 'Open menu';
  static const clearSearchTooltip = 'Clear search';
  static const genericLoadError = 'We could not load businesses right now.';
  static const retry = 'Retry';
  static const noBusinessesFound = 'No businesses found.';
  static const invalidBusinessesResponse = 'Invalid businesses response.';

  static const loginTitle = 'Welcome back';
  static const loginSubtitle = 'Sign in to manage bookings and reservations.';
  static const email = 'Email';
  static const password = 'Password';
  static const phone = 'Phone';
  static const firstName = 'First name';
  static const lastName = 'Last name';
  static const signIn = 'Sign in';
  static const signingIn = 'Signing in...';
  static const createAccount = 'Create an account';
  static const createAccountTitle = 'Create account';
  static const createAccountSubtitle =
      'Join Bookat to discover, book, or manage local services.';
  static const customer = 'Customer';
  static const business = 'Business';
  static const creatingAccount = 'Creating account...';
  static const creatingBusinessAccount = 'Creating business account...';
  static const createBusinessAccount = 'Create business account';
  static const createCustomerAccount = 'Create customer account';
  static const alreadyHaveAccount = 'Already have an account?';
  static const termsAgreement =
      'By registering, you agree to our Terms of Service and Privacy Policy.';
  static const verifyEmailTitle = 'Verify your email';
  static const verificationCode = 'Verification code';
  static const verifying = 'Verifying...';
  static const verifyAndContinue = 'Verify and continue';
  static const enterEmailValidation = 'Enter your email.';
  static const validEmailValidation = 'Enter a valid email.';
  static const passwordValidation = 'Password must be at least 6 characters.';
  static const requiredFieldValidation = 'This field is required.';
  static const otpValidation = 'Enter the 6 digit code.';

  static String otpSentToEmail(String email) {
    return 'Enter the 6 digit code sent to $email.';
  }

  static const forgotPassword = 'Forgot password?';
  static const forgotPasswordTitle = 'Reset your password';
  static const forgotPasswordSubtitle =
      'Enter the email or username on your account and we will send you a '
      'reset code.';
  static const emailOrUsername = 'Email or username';
  static const emailOrUsernameValidation = 'Enter your email or username.';
  static const sendResetCode = 'Send reset code';
  static const sendingResetCode = 'Sending code...';
  static const backToSignIn = 'Back to sign in';

  static const resetPasswordTitle = 'Enter your new password';
  static const resetCode = 'Reset code';
  static const newPassword = 'New password';
  static const confirmPassword = 'Confirm new password';
  static const passwordsDoNotMatch = 'Both passwords must match.';
  static const updatePassword = 'Update password';
  static const updatingPassword = 'Updating password...';
  static const resendCode = 'Resend code';
  static const passwordResetSuccess =
      'Password updated. Sign in with your new password.';

  static String resetCodeSentTo(String email) {
    return 'Enter the 6 digit code sent to $email, then choose a new password.';
  }

  static const homeSearchHint = 'Search clinics, salons, or grounds...';
  static const featuredServices = 'Available Businesses';

  static const book = 'Book';
  static const viewSlots = 'View slots';
  static const selectVenueCourt = 'Select Venue/Court';
  static const chooseDateTime = 'Choose Date & Time';
  static const selectVenueToContinue = 'Select a venue to continue';
  static const selectVenueToContinueHint =
      'Pick a venue or court above and the available dates and time slots will '
      'show up here.';
  static const bookingSummary = 'Booking Summary';
  static const venue = 'Venue';
  static const dateTime = 'Date & Time';
  static const notSelected = 'Not selected';
  static const totalAmount = 'Total Amount';
  static const continueToCheckout = 'Continue to Checkout';
  static const bookingCreated = 'Booking created successfully.';
  static const selectSlotFirst = 'Please select a venue and slot first.';
  static const signInAgainBeforeBooking = 'Please sign in again before booking.';
  static const myBookings = 'My Bookings';
  static const myBookingsSubtitle = 'Manage your upcoming and past reservations.';
  static const bookNewVenue = 'Book New Venue';
  static const upcoming = 'Upcoming';
  static const past = 'Past';
  static const totalPaid = 'Total Paid';
  static const noBookingsFound = 'No bookings found.';
  static const cancelBooking = 'Cancel Booking';
  static const cancellingBooking = 'Cancelling...';
  static const cancelBookingTitle = 'Cancel this booking?';
  static const cancelBookingMessage =
      'The venue sets its own cancellation window. If this booking falls '
      'outside it, the request will be declined.';
  static const keepBooking = 'Keep booking';
  static const bookingCancelledSuccess = 'Booking cancelled.';
  static const availableSlots = 'Available Slots';
  static const noSlotsAvailable = 'No slots available for this date.';
  static const booked = 'Booked';
  static const today = 'Today';
  static const tomorrow = 'Tomorrow';
  static const customerReviews = 'Customer Reviews';
  static const noReviewsYet = 'No reviews yet';
  static const firstReview = 'Be the first to share your experience.';
  static const writeReview = 'Write a Review';
  static const poweredBy = 'Powered by';
  static const reviewsLoadError = 'We could not load reviews right now.';
  static const signInToReview = 'Please sign in to leave a review.';
  static const noEligibleBookings =
      'Complete a booking at this venue to write a review.';
  static const selectBookingToReview = 'Select a booking to review';
  static const yourRating = 'Your rating';
  static const yourReview = 'Your review';
  static const yourReviewHint = 'Share details of your experience...';
  static const submitReview = 'Submit Review';
  static const submittingReview = 'Submitting...';
  static const reviewSubmittedSuccess = 'Review submitted. Thank you!';
  static const selectRatingValidation = 'Please select a rating.';

  static const categoryAll = 'All';
  static const categoryHealth = 'Health';
  static const categoryBeauty = 'Beauty';
  static const categoryRepair = 'Repair';
  static const categoryCreative = 'Creative';

  static const profile = 'Profile';
  static const account = 'Account';
  static const staff = 'Staff';
  static const admin = 'Admin';
  static const overview = 'Overview';
  static const venues = 'Venues';
  static const payments = 'Payments';
  static const settings = 'Settings';

  static const addBooking = 'Add Booking';
  static const addManualBooking = 'Add Manual Booking';
  static const addManualBookingHint =
      'Create a booking for a walk-in or phone customer. The booking will be '
      'auto-confirmed.';
  static const customerInformation = 'Customer Information';
  static const bookingDetails = 'Booking Details';
  static const emailOptional = 'Email (Optional)';
  static const phoneNumber = 'Phone Number';
  static const startTime = 'Start Time';
  static const endTime = 'End Time';
  static const calculatedPrice = 'Calculated Price';
  static const customPriceLabel = 'Custom Price / Discount (Optional)';
  static const customPriceHint = 'Enter custom price e.g. 0';
  static const bookingCreatedForCustomer = 'Booking created.';
  static const endTimeAfterStart = 'End time must be after the start time.';

  static const profitComparison = 'This Month vs Last Month';
  static const refresh = 'Refresh';
  static const collected = 'Collected';
  static const moreThanLastMonth = 'more than last month';
  static const lessThanLastMonth = 'less than last month';
  static const noChangeVsLastMonth = 'Same as last month';
  static const pendingExplainer = 'Revenue counts only payments marked paid.';
  static const pendingExplainerTail =
      'is booked but still pending — settle it in Payments to see it here.';

  static const trackPayments = 'Track revenue and settle dues';
  static const revenue = 'Revenue';
  static const pending = 'Pending';
  static const revenueByMethod = 'Revenue by Method';
  static const paymentMethod = 'Payment method';
  static const markAsPaid = 'Mark as Paid';
  static const paymentMarkedPaid = 'Payment marked as paid.';
  static const noPaymentsForMonth = 'No payments recorded for this month.';
  static const paymentsLoadError = 'We could not load payments.';
  static const revenueToday = "Today's Revenue";
  static const appointmentsToday = 'Appointments Today';
  static const activeVenues = 'Active Venues';
  static const occupancyRate = 'Occupancy Rate';
  static const revenueOverview = 'Revenue Overview';
  static const promoteBusiness = 'Promote Business';
  static const copyLink = 'Copy Link';
  static const businessBookings = 'Bookings';
  static const manageReservations = 'Manage reservations';
  static const venuesAreas = 'Venues & Areas';
  static const manageVenues = 'Manage your venues and areas.';
  static const active = 'Active';
  static const inactive = 'Inactive';
  static const category = 'Category';
  static const status = 'Status';
  static const addVenue = 'Add Venue';
  static const businessSettings = 'Business Settings';
  static const manageBusinessSettings =
      'Manage profile, operating hours, and booking page.';
  static const generalInfo = 'General Info';
  static const operatingHours = 'Operating Hours';
  static const holidaysClosures = 'Holidays & Closures';
  static const bookingPage = 'Booking Page';
  static const noOwnedBusiness = 'No business is linked to this account yet.';
  static const verified = 'Verified';
  static const notVerified = 'Not verified';
  static const appearance = 'Appearance';
  static const systemTheme = 'System';
  static const lightTheme = 'Light';
  static const darkTheme = 'Dark';
  static const logout = 'Logout';
  static const logoutTitle = 'Logout?';
  static const logoutMessage =
      'You will need to sign in again to manage bookings.';
  static const cancel = 'Cancel';
  static const logoutSuccess = 'You have been logged out.';
}
