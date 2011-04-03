#include <stdio.h>
#include <sys/time.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/hid/IOHIDKeys.h>
#include <IOKit/hid/IOHIDLib.h>
#include <CoreFoundation/CoreFoundation.h>
#import <Cocoa/Cocoa.h>

typedef struct reader {
	io_object_t ioObject;
	IOHIDDeviceInterface122 **interface;
	int gotdata;
	unsigned char buffer[50];
} reader;

SInt32 score;
IOCFPlugInInterface **plugInInterface;
CFRunLoopSourceRef eventSource;
mach_port_t port;
struct reader *r;

// print time 
void print_time (struct timeval tv)
{
	struct tm* ptm;
	char time_string[40];
	long milliseconds;
	
	/* Obtain the time of day, and convert it to a tm struct. */
	ptm = localtime (&tv.tv_sec);
	/* Format the date and time, down to a single second. */
	strftime (time_string, sizeof (time_string), "%Y-%m-%d %H:%M:%S", ptm);
	/* Compute milliseconds from microseconds. */
	milliseconds = tv.tv_usec / 1000;
	/* Print the formatted time, in seconds, followed by a decimal point
	 and the milliseconds. */
	//printf ("%s.%03ld\n", time_string, milliseconds);
	printf ("%s.%06ld\n", time_string, tv.tv_usec);
}


static void ReaderReportCallback(void *target, IOReturn result,
								 void *refcon, void *sender, UInt32 size) {
	reader *r = target;
	struct timeval begin, end;
    gettimeofday(&begin,NULL);
	
	
	
	if (r->buffer[0] == 0x00)
	{
	}
	
	else
	{
		
		printf("Event detected at ");
		print_time(begin);
		
		char bit0 = r->buffer[0];
		char bit1 = r->buffer[1];
		char bit2 = r->buffer[2];
		char bit3 = r->buffer[3];
		
		u_int8_t size = r->buffer[4];
		
		
			switch(bit1)
			{
				case 0x4: // detecteur on
					printf("Capteur activée\n");
					break;
				case 0x5: // detecteur off
					printf("Capteur désactivé\n");
					break;
				case 0x1: // arrivee
					printf("Tag déposé\n");
					printf("Tag ID : ");
					NSString * tag=@"";
					for(int j=0;j<size;j++)
					{
						tag=[tag stringByAppendingString:[NSString stringWithFormat:@"%x",r->buffer[5+j]]];
						printf("%x",r->buffer[5+j]);
					}

					
					printf("\n");
					break;
				case 0x2: // depart
					printf("Tag retiré\n");
					printf("Tag ID : ");
					for(int j=0;j<size;j++)
					{
					printf("%x",r->buffer[5+j]);
					}
					printf("\n");
					break;
				default:
					break;

			}
							printf("\n");
	}
	
		
}

int main (int argc, const char * argv[]) {
	int reason;
	 NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	IOReturn result = kIOReturnSuccess;
	io_iterator_t hidObjectIterator = 0;
	io_object_t hidDevice = IO_OBJECT_NULL;
	CFMutableDictionaryRef hidMatchDictionary = 0;
	CFMutableDictionaryRef hidProperties = 0;
	
	hidMatchDictionary = IOServiceMatching(kIOHIDDeviceKey);
	result = IOServiceGetMatchingServices(	kIOMasterPortDefault,
										  hidMatchDictionary,
										  &hidObjectIterator);
	
	if ((result != kIOReturnSuccess) || (hidObjectIterator == 0)) {
		printf("Can't obtain an IO iterator\n");
		exit(1);
	}
	
	while ((hidDevice = IOIteratorNext(hidObjectIterator))) {
		hidProperties = 0;
		int vendor = 0, product = 0;
		result = IORegistryEntryCreateCFProperties(hidDevice, &hidProperties,
												   kCFAllocatorDefault, kNilOptions);
		
		if ((result == KERN_SUCCESS) && hidProperties) {
			CFNumberRef vendorRef, productRef;
			
			vendorRef = CFDictionaryGetValue(hidProperties, CFSTR(kIOHIDVendorIDKey));
			productRef = CFDictionaryGetValue(hidProperties, CFSTR(kIOHIDProductIDKey));
			
			if (vendorRef) {
				CFNumberGetValue(vendorRef, kCFNumberIntType, &vendor);	   CFRelease(vendorRef);
			}
			
			if (productRef) {
				CFNumberGetValue(productRef, kCFNumberIntType, &product);
				CFRelease(productRef);
			}
			
			if (vendor == 0x1da8 && product == 0x1301)
			{
				printf("Found mir:ror\n");
				
				r = malloc(sizeof(*r));
				r->ioObject = hidDevice;
				IOCreatePlugInInterfaceForService(hidDevice, kIOHIDDeviceUserClientTypeID,
												  kIOCFPlugInInterfaceID, &plugInInterface, &score);
				(*plugInInterface)->QueryInterface(plugInInterface,
												   CFUUIDGetUUIDBytes(kIOHIDDeviceInterfaceID), (LPVOID) &(r->interface));
				(*plugInInterface)->Release(plugInInterface);
				(*(r->interface))->open(r->interface, 0);
				(*(r->interface))->createAsyncPort(r->interface, &port);
				(*(r->interface))->createAsyncEventSource(r->interface, &eventSource);
				(*(r->interface))->setInterruptReportHandlerCallback(r->interface,
																	 r->buffer, 50, ReaderReportCallback, r, NULL);
				(*(r->interface))->startAllQueues(r->interface);
				CFRunLoopAddSource(CFRunLoopGetCurrent(), eventSource, kCFRunLoopDefaultMode);
				
				// Send USB report in order to initialize the device
/*		(*(r->interface))->setReport(
											 r->interface,		// self
											 kIOHIDReportTypeOutput,	// report type
											 0x02 + (0x03 << 8),			// report ID
											 (uint8_t *) &rfset,			// buffer
											 (int) sizeof(wispy24x_rfsettings),		// size
											 9000,			// timeout (in ms)
											 0,			// callback function
											 0,			// ... and arguments
											 0);*/
				
				// main loop
				r->gotdata = 0;
				while (!r->gotdata) {
					reason = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
				}
				
			}
			
		}
	
	
		IOObjectRelease(hidDevice);
		
	}
	
	IOObjectRelease(hidObjectIterator);
	
	[pool release];
	return 0;
	
}
