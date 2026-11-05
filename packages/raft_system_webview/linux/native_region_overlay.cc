#include "native_region_overlay.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstring>

namespace {
FlValue* Field(FlValue* value, const char* key) {
  return value && fl_value_get_type(value)==FL_VALUE_TYPE_MAP ? fl_value_lookup_string(value,key) : nullptr;
}
bool Number(FlValue* value, double& output, double maximum=10000000) {
  if (!value) return false;
  if (fl_value_get_type(value)==FL_VALUE_TYPE_FLOAT) output=fl_value_get_float(value);
  else if(fl_value_get_type(value)==FL_VALUE_TYPE_INT) output=fl_value_get_int(value);
  else return false;
  return std::isfinite(output) && std::abs(output)<=maximum;
}
bool Vector(FlValue* value, double* out, size_t count, double maximum=10000000) {
  if(!value || fl_value_get_type(value)!=FL_VALUE_TYPE_LIST || fl_value_get_length(value)!=count) return false;
  for(size_t i=0;i<count;i++) if(!Number(fl_value_get_list_value(value,i),out[i],maximum))return false;
  return true;
}
bool Integer(FlValue* value, int64_t& output) {
  if(!value || fl_value_get_type(value)!=FL_VALUE_TYPE_INT)return false;
  output=fl_value_get_int(value);return output>0;
}
bool Color(FlValue* value, guint32& output) {
  if(!value || fl_value_get_type(value)!=FL_VALUE_TYPE_INT)return false;
  const auto number=fl_value_get_int(value);if(number<0 || number>0xffffffffLL)return false;
  output=static_cast<guint32>(number);return true;
}
void PaintColor(cairo_t* canvas,guint32 color) {
  cairo_set_source_rgba(canvas,((color>>16)&255)/255.,((color>>8)&255)/255.,(color&255)/255.,((color>>24)&255)/255.);
}
void Rounded(cairo_t* c,double x,double y,double width,double height,double radius) {
  const auto r=std::min(std::max(0.,radius),std::min(width,height)/2);
  const double q=.5522847498307936*r;
  cairo_new_path(c);cairo_move_to(c,x+r,y);cairo_line_to(c,x+width-r,y);
  cairo_curve_to(c,x+width-r+q,y,x+width,y+r-q,x+width,y+r);
  cairo_line_to(c,x+width,y+height-r);
  cairo_curve_to(c,x+width,y+height-r+q,x+width-r+q,y+height,x+width-r,y+height);
  cairo_line_to(c,x+r,y+height);
  cairo_curve_to(c,x+r-q,y+height,x,y+height-r+q,x,y+height-r);
  cairo_line_to(c,x,y+r);cairo_curve_to(c,x,y+r-q,x+r-q,y,x+r,y);cairo_close_path(c);
}
FlValue* Pair(double x,double y) {
  auto* value=fl_value_new_list();fl_value_append_take(value,fl_value_new_float(x));fl_value_append_take(value,fl_value_new_float(y));return value;
}
}
NativeRegionOverlay::NativeRegionOverlay(GtkWidget* web,std::function<void(FlValue*)> input):input_(std::move(input)) {
  root_=gtk_overlay_new();g_object_ref_sink(root_);
  gtk_container_add(GTK_CONTAINER(root_),web);
  capture_=gtk_event_box_new();g_object_ref_sink(capture_);gtk_event_box_set_visible_window(GTK_EVENT_BOX(capture_),FALSE);
  gtk_event_box_set_above_child(GTK_EVENT_BOX(capture_),TRUE);
  drawing_=gtk_drawing_area_new();g_object_ref_sink(drawing_);
  // A paint-only child must not create a second input window above the page.
  // GtkOverlay pass-through applies to the overlay, not arbitrary child windows.
  gtk_widget_set_has_window(drawing_,FALSE);gtk_widget_set_app_paintable(drawing_,TRUE);
  gtk_widget_set_hexpand(capture_,TRUE);gtk_widget_set_vexpand(capture_,TRUE);
  gtk_widget_set_halign(capture_,GTK_ALIGN_FILL);gtk_widget_set_valign(capture_,GTK_ALIGN_FILL);
  gtk_widget_set_hexpand(drawing_,TRUE);gtk_widget_set_vexpand(drawing_,TRUE);
  gtk_widget_set_halign(drawing_,GTK_ALIGN_FILL);gtk_widget_set_valign(drawing_,GTK_ALIGN_FILL);
  gtk_widget_set_no_show_all(drawing_,TRUE);gtk_widget_set_no_show_all(capture_,TRUE);
  // Paint and capture are separate overlays. A flashed marker leaves the
  // input-only EventBox hidden, rather than relying on child pass-through.
  gtk_overlay_add_overlay(GTK_OVERLAY(root_),drawing_);
  gtk_overlay_set_overlay_pass_through(GTK_OVERLAY(root_),drawing_,TRUE);
  gtk_overlay_add_overlay(GTK_OVERLAY(root_),capture_);
  gtk_overlay_set_overlay_pass_through(GTK_OVERLAY(root_),capture_,TRUE);
  gtk_widget_add_events(capture_,GDK_BUTTON_PRESS_MASK|GDK_BUTTON_RELEASE_MASK|GDK_POINTER_MOTION_MASK|GDK_SCROLL_MASK|GDK_SMOOTH_SCROLL_MASK);
  g_signal_connect(drawing_,"draw",G_CALLBACK(Draw),this);
  g_signal_connect(capture_,"button-press-event",G_CALLBACK(Button),this);
  g_signal_connect(capture_,"button-release-event",G_CALLBACK(Button),this);
  g_signal_connect(capture_,"motion-notify-event",G_CALLBACK(Motion),this);
  g_signal_connect(capture_,"scroll-event",G_CALLBACK(Scroll),this);
  g_signal_connect(capture_,"grab-broken-event",G_CALLBACK(GrabBroken),this);
}
NativeRegionOverlay::~NativeRegionOverlay() {
  input_=nullptr;
  g_signal_handlers_disconnect_by_data(capture_,this);g_signal_handlers_disconnect_by_data(drawing_,this);
  g_clear_object(&hint_);gtk_widget_destroy(root_);g_clear_object(&drawing_);g_clear_object(&capture_);g_clear_object(&root_);
}
void NativeRegionOverlay::Clear() {
  if (pressed_) Input("cancel", 0, 0);
  pressed_=false; enabled_=false; markers_.clear(); g_clear_object(&hint_); hint_sha_.clear();
  gtk_overlay_set_overlay_pass_through(GTK_OVERLAY(root_),capture_,TRUE);
  gtk_widget_hide(capture_);gtk_widget_hide(drawing_);gtk_widget_queue_draw(drawing_);
}
void NativeRegionOverlay::Visibility(bool visible) {
  visible_=visible;
  if(!visible && pressed_){pressed_=false;Input("cancel",0,0);}
}
bool NativeRegionOverlay::Update(FlValue* value) {
  int64_t generation,sequence;
  double viewport[2];
  auto* enabled=Field(value,"captureEnabled");auto* markers=Field(value,"markers");
  if(!Integer(Field(value,"generation"),generation)||!Integer(Field(value,"sequence"),sequence)||
     !Vector(Field(value,"viewport"),viewport,2,32768)||viewport[0]<0||viewport[1]<0||
     !enabled||fl_value_get_type(enabled)!=FL_VALUE_TYPE_BOOL||!markers||fl_value_get_type(markers)!=FL_VALUE_TYPE_LIST||fl_value_get_length(markers)>2)return false;
  if(generation<generation_ || (generation==generation_ && sequence<=sequence_))return true;
  auto* raw_hint=Field(value,"hint");
  if((viewport[0]==0 || viewport[1]==0) && (fl_value_get_bool(enabled)||fl_value_get_length(markers)>0||
    (raw_hint&&fl_value_get_type(raw_hint)!=FL_VALUE_TYPE_NULL)))return false;
  std::vector<Marker> parsed;
  for(size_t i=0;i<fl_value_get_length(markers);i++) {
    auto* source=fl_value_get_list_value(markers,i);Marker marker{};
    auto* dashed=Field(source,"dashed");auto* segments=Field(source,"borderSegments");
    if(!Vector(Field(source,"rect"),marker.rect,4)||marker.rect[2]<0||marker.rect[3]<0||
       !Color(Field(source,"fillARGB"),marker.fill)||!Color(Field(source,"borderARGB"),marker.border)||
       !Number(Field(source,"strokeWidth"),marker.stroke,1024)||marker.stroke<0||
       !Number(Field(source,"radius"),marker.radius,1024)||marker.radius<0||!dashed||fl_value_get_type(dashed)!=FL_VALUE_TYPE_BOOL||
       !segments||fl_value_get_type(segments)!=FL_VALUE_TYPE_LIST||fl_value_get_length(segments)>8192)return false;
    marker.dashed=fl_value_get_bool(dashed);
    for(size_t j=0;j<fl_value_get_length(segments);j++) {
      std::array<double,4> segment{};if(!Vector(fl_value_get_list_value(segments,j),segment.data(),4)||segment[2]<0||segment[3]<0)return false;
      marker.segments.push_back(segment);
    }
    parsed.push_back(std::move(marker));
  }
  GdkPixbuf* hint=nullptr;double hint_size[2]{},hint_offset[2]{};std::string hint_sha;
  auto* h=Field(value,"hint");
  if(h && fl_value_get_type(h)!=FL_VALUE_TYPE_NULL) {
    auto* bytes=Field(h,"png");
    if(!bytes||fl_value_get_type(bytes)!=FL_VALUE_TYPE_UINT8_LIST||fl_value_get_length(bytes)>1024*1024||fl_value_get_length(bytes)<24||
       !Vector(Field(h,"logicalSize"),hint_size,2,32768)||hint_size[0]<=0||hint_size[1]<=0||
       !Vector(Field(h,"logicalOffset"),hint_offset,2,32768))return false;
    const auto* png=fl_value_get_uint8_list(bytes);
    constexpr unsigned char signature[]={137,80,78,71,13,10,26,10};
    if(memcmp(png,signature,8)||memcmp(png+12,"IHDR",4))return false;
    auto be=[](const guint8* v){return (guint32(v[0])<<24)|(guint32(v[1])<<16)|(guint32(v[2])<<8)|v[3];};
    const guint32 width=be(png+16),height=be(png+20);
    if(!width||!height||width>8192||height>8192||guint64(width)*height>4*1024*1024)return false;
    g_autofree char* checksum=g_compute_checksum_for_data(G_CHECKSUM_SHA256,png,fl_value_get_length(bytes));
    hint_sha=checksum;
    if(hint_ && hint_sha==hint_sha_) hint=GDK_PIXBUF(g_object_ref(hint_));
    else {
      g_autoptr(GInputStream) stream=g_memory_input_stream_new_from_data(png,fl_value_get_length(bytes),nullptr);
      hint=gdk_pixbuf_new_from_stream(stream,nullptr,nullptr);if(!hint)return false;
      if(gdk_pixbuf_get_width(hint)!=static_cast<int>(width)||gdk_pixbuf_get_height(hint)!=static_cast<int>(height)){g_object_unref(hint);return false;}
    }
  }
  if(generation!=generation_){input_sequence_=0;pressed_=false;}
  generation_=generation;sequence_=sequence;viewport_[0]=viewport[0];viewport_[1]=viewport[1];
  enabled_=fl_value_get_bool(enabled);if(!enabled_)pressed_=false;
  markers_=std::move(parsed);g_clear_object(&hint_);hint_=hint;hint_sha_=std::move(hint_sha);
  std::copy(hint_size,hint_size+2,hint_size_);std::copy(hint_offset,hint_offset+2,hint_offset_);
  gtk_overlay_set_overlay_pass_through(GTK_OVERLAY(root_),capture_,!enabled_);
  if(enabled_)gtk_widget_show(capture_);else gtk_widget_hide(capture_);
  if(!markers_.empty()||hint_)gtk_widget_show(drawing_);else gtk_widget_hide(drawing_);
  if(gtk_widget_get_realized(capture_)) {
    g_autoptr(GdkCursor) cursor=enabled_?gdk_cursor_new_from_name(gtk_widget_get_display(capture_),"crosshair"):nullptr;
    if(auto* window=gtk_widget_get_window(capture_))gdk_window_set_cursor(window,cursor);
  }
  gtk_widget_queue_draw(drawing_);return true;
}
void NativeRegionOverlay::Input(const char* phase,double x,double y,double dx,double dy) {
  const double width=gtk_widget_get_allocated_width(root_),height=gtk_widget_get_allocated_height(root_);
  if(!input_||generation_<=0||viewport_[0]<=0||viewport_[1]<=0||width<=0||height<=0)return;
  g_autoptr(FlValue) value=fl_value_new_map();
  fl_value_set_string_take(value,"generation",fl_value_new_int(generation_));
  fl_value_set_string_take(value,"sequence",fl_value_new_int(++input_sequence_));
  fl_value_set_string_take(value,"phase",fl_value_new_string(phase));
  fl_value_set_string_take(value,"viewport",Pair(viewport_[0],viewport_[1]));
  fl_value_set_string_take(value,"position",Pair(std::clamp(x/width,0.,1.),std::clamp(y/height,0.,1.)));
  fl_value_set_string_take(value,"delta",Pair(dx/width,dy/height));input_(value);
}
gboolean NativeRegionOverlay::Button(GtkWidget*,GdkEventButton* event,gpointer data) {
  auto* self=static_cast<NativeRegionOverlay*>(data);if(!self->enabled_||!self->visible_)return FALSE;
  if(event->button!=1){self->pressed_=false;self->Input("cancel",event->x,event->y);return TRUE;}
  if(event->type==GDK_BUTTON_PRESS){self->pressed_=true;self->Input("down",event->x,event->y);}
  else if(event->type==GDK_BUTTON_RELEASE&&self->pressed_){self->pressed_=false;self->Input("up",event->x,event->y);}
  return TRUE;
}
gboolean NativeRegionOverlay::Motion(GtkWidget*,GdkEventMotion* event,gpointer data) {
  auto* self=static_cast<NativeRegionOverlay*>(data);if(!self->enabled_||!self->visible_)return FALSE;
  if(self->pressed_)self->Input("move",event->x,event->y);return TRUE;
}
gboolean NativeRegionOverlay::GrabBroken(GtkWidget*,GdkEventGrabBroken*,gpointer data) {
  auto* self=static_cast<NativeRegionOverlay*>(data);if(self->pressed_){self->pressed_=false;self->Input("cancel",0,0);}return FALSE;
}
gboolean NativeRegionOverlay::Scroll(GtkWidget*,GdkEventScroll* event,gpointer data) {
  auto* self=static_cast<NativeRegionOverlay*>(data);if(!self->enabled_||!self->visible_)return FALSE;
  double dx=0,dy=0;
  switch(event->direction){case GDK_SCROLL_UP:dy=-1;break;case GDK_SCROLL_DOWN:dy=1;break;
    case GDK_SCROLL_LEFT:dx=-1;break;case GDK_SCROLL_RIGHT:dx=1;break;
    case GDK_SCROLL_SMOOTH:dx=event->delta_x;dy=event->delta_y;break;}
  // Flutter's GTK host uses the Chromium 53-logical-unit wheel multiplier.
  self->Input("scroll",event->x,event->y,dx*53,dy*53);return TRUE;
}
gboolean NativeRegionOverlay::Draw(GtkWidget*,cairo_t* canvas,gpointer data){static_cast<NativeRegionOverlay*>(data)->Paint(canvas);return FALSE;}
void NativeRegionOverlay::Paint(cairo_t* c) {
  if(viewport_[0]<=0||viewport_[1]<=0)return;
  cairo_save(c);cairo_scale(c,gtk_widget_get_allocated_width(root_)/viewport_[0],gtk_widget_get_allocated_height(root_)/viewport_[1]);
  cairo_rectangle(c,0,0,viewport_[0],viewport_[1]);cairo_clip(c);
  for(const auto& m:markers_) {
    const double x=m.rect[0]*viewport_[0],y=m.rect[1]*viewport_[1],w=m.rect[2]*viewport_[0],h=m.rect[3]*viewport_[1];
    if(w<=0||h<=0)continue;
    PaintColor(c,m.fill);Rounded(c,x,y,w,h,m.dashed?0:m.radius);cairo_fill(c);
    PaintColor(c,m.border);
    if(m.dashed){for(const auto& s:m.segments)cairo_rectangle(c,s[0]*viewport_[0],s[1]*viewport_[1],s[2]*viewport_[0],s[3]*viewport_[1]);cairo_fill(c);}
    else if(m.stroke>0&&w>=m.stroke&&h>=m.stroke){Rounded(c,x+m.stroke/2,y+m.stroke/2,w-m.stroke,h-m.stroke,m.radius);cairo_set_line_width(c,m.stroke);cairo_stroke(c);}
  }
  if(hint_){cairo_save(c);cairo_translate(c,hint_offset_[0],hint_offset_[1]);cairo_scale(c,hint_size_[0]/gdk_pixbuf_get_width(hint_),hint_size_[1]/gdk_pixbuf_get_height(hint_));gdk_cairo_set_source_pixbuf(c,hint_,0,0);cairo_paint(c);cairo_restore(c);}
  cairo_restore(c);
}
