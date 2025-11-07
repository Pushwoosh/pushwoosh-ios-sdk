# HTML Guide for tvOS Rich Media

Create Rich Media content using Unlayer HTML format for tvOS.

## Overview

Pushwoosh tvOS Rich Media supports HTML content in Unlayer format. The parser recognizes special id attributes and inline styles to create native tvOS interface elements with automatic focus navigation support.

## Basic Structure

Every Rich Media HTML must have this basic structure:

```html
<div id="u_body" style="background-color: #1a1a2e; border-radius: 30px;">
  <div id="u_column_1">
    <!-- Your content here -->
  </div>
</div>
```

### Supported Styles for u_body

| Style | Description | Example |
|-------|-------------|---------|
| `background-color` | Background color | `#1a1a2e`, `rgb(26, 26, 46)`, `rgba(26, 26, 46, 0.9)` |
| `border-radius` | Corner radius | `30px` |
| `background-image` | Background image | `url('https://example.com/bg.jpg')` |

## Content Types

### Images

Display images using `u_content_image_*` id:

```html
<div id="u_content_image_1">
  <img src="https://example.com/image.jpg" />
</div>
```

Or use background-image:

```html
<div id="u_content_image_1" style="background-image: url('https://example.com/image.jpg');">
</div>
```

### Headings

Create headings with `u_content_heading_*` id:

```html
<div id="u_content_heading_1" style="font-size: 32px; color: #ffffff; text-align: center;">
  <h1>Your Heading</h1>
</div>
```

**Supported styles:**
- `font-size` - Font size in pixels (automatically increased by 20% for tvOS)
- `color` - Text color (hex, rgb, rgba)
- `text-align` - Alignment (`left`, `center`, `right`, `justify`)

### Text

Display text content with `u_content_text_*` id:

```html
<div id="u_content_text_1" style="font-size: 18px; color: #cccccc; text-align: left;">
  <p>Your text here</p>
</div>
```

Supports the same styles as headings.

### Buttons

Buttons use `u_content_button_*` id and support various actions:

#### Track Event Button

```html
<div id="u_content_button_1">
  <a href="#"
     data-event="button_clicked"
     data-attributes='{"source": "rich_media", "action": "subscribe"}'
     style="background-color: #4a5ff7; color: #ffffff; border-radius: 12px;">
    Subscribe
  </a>
</div>
```

#### Close Button

```html
<div id="u_content_button_2">
  <a href="closeInApp" style="background-color: transparent; color: #ffffff; border-bottom-color: #ffffff;">
    Close
  </a>
</div>
```

#### Open Settings Button

```html
<div id="u_content_button_3">
  <a href="openAppSettings" style="background-color: #4a5ff7; color: #ffffff;">
    Open Settings
  </a>
</div>
```

#### Send Tags Button

```html
<div id="u_content_button_4">
  <a href="sendTags"
     data-tags='{"subscribed": true, "source": "tv_promo"}'
     style="background-color: #4a5ff7; color: #ffffff;">
    Save
  </a>
</div>
```

#### Get Tags Button

```html
<div id="u_content_button_5">
  <a href="getTags" style="background-color: #4a5ff7; color: #ffffff;">
    Get Tags
  </a>
</div>
```

#### Button Styles

| Style | Description |
|-------|-------------|
| `background-color` | Background color (use `transparent` for transparent button) |
| `color` | Text color |
| `border-bottom-color` or `border-color` | Border color |
| `border-radius` | Corner radius (applied to button, not container) |

### Text Fields

Create input fields with `u_content_textfield_*` id:

```html
<div id="u_content_textfield_1">
  <input type="text"
         placeholder="Enter email"
         data-field-name="email"
         style="font-size: 18px; color: #ffffff; background-color: rgba(255,255,255,0.1); border-color: #4a5ff7; text-align: left;" />
</div>
```

**Required attributes:**
- `data-field-name` - Field name used to retrieve value

**Supported styles:**
- `font-size` - Font size
- `color` - Text color
- `background-color` - Background color
- `border-color` - Border color
- `text-align` - Text alignment

## Layout Options

### Horizontal Layout (Two Columns)

Create a horizontal layout using `flex-direction: row` in `u_column_1`:

```html
<div id="u_body" style="background-color: #1a1a2e; border-radius: 30px;">
  <div id="u_column_1" style="display: flex; flex-direction: row;">

    <!-- Left column -->
    <div>
      <div id="u_content_heading_1" style="font-size: 32px; color: #ffffff;">
        <h1>Heading</h1>
      </div>
      <div id="u_content_text_1" style="font-size: 18px; color: #cccccc;">
        <p>Description</p>
      </div>
      <div id="u_content_button_1">
        <a href="#" data-event="action" style="background-color: #4a5ff7; color: #ffffff;">
          Button
        </a>
      </div>
    </div>

    <!-- Right column -->
    <div>
      <div id="u_content_image_1">
        <img src="https://example.com/image.jpg" />
      </div>
    </div>

  </div>
</div>
```

### Vertical Layout (Default)

By default, content flows vertically. No special configuration needed.

## Color Formats

All color formats are supported:

| Format | Example |
|--------|---------|
| Hex | `#ff0000`, `#f00` |
| RGB | `rgb(255, 0, 0)` |
| RGBA | `rgba(255, 0, 0, 0.5)` |

## Important Requirements

### Element IDs

All content elements **must** have id in the format `u_content_[type]_[number]`:

- Images: `u_content_image_1`, `u_content_image_2`, ...
- Headings: `u_content_heading_1`, `u_content_heading_2`, ...
- Text: `u_content_text_1`, `u_content_text_2`, ...
- Buttons: `u_content_button_1`, `u_content_button_2`, ...
- Text fields: `u_content_textfield_1`, `u_content_textfield_2`, ...

> **Important**: Elements without proper id format will not be displayed.

### Dividers

Elements with `u_content_divider_*` id are ignored and not displayed.

### HTML Entities

Supported HTML entities:
- `&nbsp;` - Non-breaking space
- `&amp;` - Ampersand
- `&lt;` - Less than
- `&gt;` - Greater than
- `&quot;` - Quote

### Font Size Adjustment

Font sizes are automatically increased by 20% for better readability on Apple TV screens.

### Focus Navigation

Buttons and text fields automatically become focusable for Apple TV remote navigation. Elements are navigated in the order they appear in the HTML.

### Inline Styles Only

Use only inline styles in `style=""` attribute. External CSS files and `<style>` tags are not supported.

### Localization Support

Placeholders in format `{{key|text|default value}}` are supported for localized content.

## Complete Example

```html
<div id="u_body" style="background-color: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 30px; padding: 40px;">
  <div id="u_column_1" style="display: flex; flex-direction: row;">

    <!-- Content column -->
    <div style="flex: 1;">
      <div id="u_content_heading_1" style="font-size: 48px; color: #ffffff; text-align: left;">
        <h1>Exclusive Offer</h1>
      </div>

      <div id="u_content_text_1" style="font-size: 24px; color: rgba(255,255,255,0.9); text-align: left;">
        <p>Subscribe now and get 30 days free</p>
      </div>

      <div id="u_content_textfield_1">
        <input type="text"
               placeholder="Enter your email"
               data-field-name="email"
               style="font-size: 18px; color: #ffffff; background-color: rgba(255,255,255,0.1); border-color: rgba(255,255,255,0.3);" />
      </div>

      <div id="u_content_button_1">
        <a href="#"
           data-event="subscription_started"
           data-attributes='{"source": "tv_promo", "plan": "premium"}'
           style="background-color: #4a5ff7; color: #ffffff; border-radius: 12px;">
          Start Free Trial
        </a>
      </div>

      <div id="u_content_button_2">
        <a href="closeInApp" style="background-color: transparent; color: rgba(255,255,255,0.7); border-bottom-color: rgba(255,255,255,0.3);">
          Later
        </a>
      </div>
    </div>

    <!-- Image column -->
    <div style="flex: 1;">
      <div id="u_content_image_1">
        <img src="https://example.com/tv-promo.jpg" />
      </div>
    </div>

  </div>
</div>
```

## Best Practices

- **Keep it simple**: Avoid complex nested structures
- **Test focus order**: Verify navigation flow with Apple TV remote
- **Use semantic HTML**: Use proper heading tags (`<h1>`, `<h2>`, etc.)
- **Provide placeholders**: Always include placeholder text for input fields
- **Clear call-to-action**: Make buttons visually distinct with good contrast
- **Adequate spacing**: Maintain 20-30px spacing between interactive elements
- **Minimum sizes**: Buttons should be at least 250pt wide for easy selection

## Troubleshooting

### Element Not Appearing

- Check that the element has proper `u_content_*` id
- Verify inline styles are present
- Ensure there are no syntax errors in style attribute

### Button Not Working

- Verify `href` attribute has correct action (`closeInApp`, `sendTags`, `getTags`, `openAppSettings`)
- Check `data-event` and `data-attributes` JSON format
- Ensure button is inside `u_content_button_*` div

### Focus Navigation Issues

- Verify buttons and inputs are in logical order in HTML
- Check that focusable elements have sufficient size
- Test on physical Apple TV device

## Next Steps

- <doc:GettingStarted> - Integration guide
- <doc:Examples> - Code examples
- ``PWTVOSRichMediaManager`` - Rich Media manager reference
