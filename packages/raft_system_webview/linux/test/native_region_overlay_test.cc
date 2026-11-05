#include "native_region_overlay.h"
#include <gdk/gdkx.h>
#include <cassert>
#include <string>
#include <iostream>

void Drain() { for(int i=0;i<15;i++){while(gtk_events_pending())gtk_main_iteration();g_usleep(10000);} }
FlValue* Pair(double x,double y) {auto* a=fl_value_new_list();fl_value_append_take(a,fl_value_new_float(x));fl_value_append_take(a,fl_value_new_float(y));return a;}
FlValue* Frame(int generation,int sequence,bool capture,double width=600,double height=400) {
 auto* v=fl_value_new_map();fl_value_set_string_take(v,"generation",fl_value_new_int(generation));fl_value_set_string_take(v,"sequence",fl_value_new_int(sequence));fl_value_set_string_take(v,"viewport",Pair(width,height));fl_value_set_string_take(v,"captureEnabled",fl_value_new_bool(capture));fl_value_set_string_take(v,"markers",fl_value_new_list());fl_value_set_string_take(v,"hint",fl_value_new_null());return v;
}
void Click(Window id,bool drag=false) {
 std::string command="xdotool mousemove --window "+std::to_string(id)+" 100 100 ";
 command+=drag?"mousedown 1 mousemove --window "+std::to_string(id)+" 180 160 mouseup 1":"click 1";
 gint status;g_autoptr(GError) error=nullptr;assert(g_spawn_command_line_sync(command.c_str(),nullptr,nullptr,&status,&error)&&status==0);Drain();
}
int main(int argc,char** argv) {
 gtk_init(&argc,&argv);int underlying=0;std::vector<FlValue*> events;
 GtkWidget* window=gtk_window_new(GTK_WINDOW_TOPLEVEL);gtk_window_set_default_size(GTK_WINDOW(window),600,400);
 GtkWidget* button=gtk_button_new_with_label("Underlying GTK content");
 g_signal_connect(button,"clicked",G_CALLBACK(+[](GtkButton*,gpointer data){++*static_cast<int*>(data);}),&underlying);
 {
 NativeRegionOverlay overlay(button,[&events](FlValue* event){events.push_back(fl_value_ref(event));});
 gtk_container_add(GTK_CONTAINER(window),overlay.widget());gtk_widget_show_all(window);Drain();overlay.Visibility(true);
 Window id=GDK_WINDOW_XID(gtk_widget_get_window(window));
 g_autoptr(FlValue) inactive=Frame(1,1,false);assert(overlay.Update(inactive));Drain();Click(id);assert(underlying==1&&events.empty());
 g_autoptr(FlValue) active=Frame(1,2,true);assert(overlay.Update(active));Drain();Click(id,true);assert(underlying==1);
 assert(events.size()>=2);assert(std::string(fl_value_get_string(fl_value_lookup_string(events.front(),"phase")))=="down");assert(std::string(fl_value_get_string(fl_value_lookup_string(events.back(),"phase")))=="up");
 const size_t recorded=events.size();
 g_autoptr(FlValue) clear=Frame(2,1,false,0,0);assert(overlay.Update(clear));Drain();Click(id);assert(underlying==2&&events.size()==recorded);
 g_autoptr(FlValue) stale=Frame(1,999,true);assert(overlay.Update(stale));Drain();Click(id);assert(underlying==3&&events.size()==recorded);
 g_autoptr(FlValue) paint=Frame(3,1,false);
 auto* marker=fl_value_new_map();auto* rect=fl_value_new_list();
 for(double n:{.2,.2,.3,.3})fl_value_append_take(rect,fl_value_new_float(n));
 fl_value_set_string_take(marker,"rect",rect);
 fl_value_set_string_take(marker,"fillARGB",fl_value_new_int(0xff112233));
 fl_value_set_string_take(marker,"borderARGB",fl_value_new_int(0xff445566));
 fl_value_set_string_take(marker,"strokeWidth",fl_value_new_int(1));fl_value_set_string_take(marker,"radius",fl_value_new_int(2));
 fl_value_set_string_take(marker,"dashed",fl_value_new_bool(false));fl_value_set_string_take(marker,"borderSegments",fl_value_new_list());
 fl_value_append_take(fl_value_lookup_string(paint,"markers"),marker);assert(overlay.Update(paint));Drain();
 cairo_surface_t* surface=cairo_image_surface_create(CAIRO_FORMAT_ARGB32,600,400);cairo_t* canvas=cairo_create(surface);
 gtk_widget_draw(overlay.widget(),canvas);cairo_destroy(canvas);cairo_surface_flush(surface);
 auto* pixel=cairo_image_surface_get_data(surface)+100*cairo_image_surface_get_stride(surface)+150*4;
 assert(pixel[0]==0x33&&pixel[1]==0x22&&pixel[2]==0x11&&pixel[3]==0xff);cairo_surface_destroy(surface);
 Click(id);assert(underlying==4); // A painted flash does not intercept input.
 overlay.Clear();
 gtk_widget_destroy(window);Drain();
 }
 for(auto* event:events)fl_value_unref(event);
 for(int i=0;i<8;i++) {NativeRegionOverlay overlay(gtk_label_new("owned"),[](FlValue*){});g_autoptr(FlValue) clear=Frame(i+1,1,false,0,0);assert(overlay.Update(clear));}
 std::cout<<"{\"productionClass\":\"NativeRegionOverlay\",\"underlyingClicks\":"<<underlying<<",\"nativeDragEvents\":"<<events.size()<<",\"cases\":8,\"passed\":true}"<<std::endl;
}
