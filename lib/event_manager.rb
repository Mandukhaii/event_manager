require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  # if the zip code is exactly five digits, assume that it is ok
  # if the zip code is more than five digits, truncate it to the first five digits
  # if the zip code is less than five digits, add zeros to the front until it becomes five digits

  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_phone_numbers(phone)
  # If the phone number is less than 10 digits, assume that it is a bad number
  # If the phone number is 10 digits, assume that it is good
  # If the phone number is 11 digits and the first number is 1, trim the 1 and use the remaining 10 digits
  # If the phone number is 11 digits and the first number is not 1, then it is a bad number
  # If the phone number is more than 11 digits, assume that it is a bad number

  phone = phone.tr('^0-9', '')

  return phone if phone.length == 10
  return phone[1..10] if phone.length == 11 && phone.start_with?('1')

  'Phone number unavailable'
end

def time_date_targeting(date_time, hour_count, day_count)
  #the format is 11/12/08 10:47
  #we want most popular or repeating hours & days
  date = DateTime.strptime(date_time, '%m/%d/%y %H:%M')

  # increment hour and day counts
  hour_count[date.hour] += 1
  day_count[date.wday] += 1

  return date.hour, date.wday
end

puts 'EventManager Initialized.'

contents = CSV.open(
  'event_attendees.csv', 
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

# a hash to keep track of hour counts
hour_count = Hash.new(0)

#a hash to keep track of days
day_count = Hash.new(0)

# days, Sunday is 0 when using .wday
days = {
  0 => 'Sunday',
  1 => 'Monday',
  2 => 'Tuesday',
  3 => 'Wednesday',
  4 => 'Thursday',
  5 => 'Friday',
  6 => 'Saturday'
}

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  phone = clean_phone_numbers(row[:homephone])

  hour, day = time_date_targeting(row[:regdate], hour_count, day_count)

  puts "#{name}, Hour: #{hour}, Day of week: #{days[day]}"
end

#most common hour
most_common_hour = hour_count.max_by { |_, count| count }&.first
puts "Most common hour: #{most_common_hour}"

#most common day
most_common_day = day_count.max_by { |_, count| count }&.first
puts "Most common day: #{days[most_common_day]}"




