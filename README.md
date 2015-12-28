# ConfluenceReporter

Logger to confluence. Allows access to pages, creation and appending of messages. You have to flush the log to confluence by calling report_event method.

For now all log messages are displayed in the same way. Will add colors in next version.

## Usage

```

reporter = ConfluenceReporter::Reporter.new(base_url, user, password)

puts reporter.find_page_by_id(page_id)

puts reporter.find_page_by_name(name, parrent_page_id)

reporter.log(log)

# Flush log to confluence, creates or appends to page 
reporter.report_event(name, parrent_page_id, space)


```