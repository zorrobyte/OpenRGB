/*---------------------------------------------------------*\
| RazerDeviceGuard.cpp                                      |
|                                                           |
|   DeviceGuard for Razer devices                           |
|                                                           |
|   Aytac Kayadelen                             18 May 2024 |
|                                                           |
|   This file is part of the OpenRGB project                |
|   SPDX-License-Identifier: GPL-2.0-or-later               |
\*---------------------------------------------------------*/

#include "RazerDeviceGuard.h"

#ifdef _WIN32
#include <condition_variable>
#include <mutex>

/*---------------------------------------------------------*\
| One queue for all Razer devices in this process, since   |
| they all share the one system-wide mutex                  |
\*---------------------------------------------------------*/
static std::mutex               turn_mutex;
static std::condition_variable  turn_cv;
static unsigned long long       next_ticket = 0;
static unsigned long long       now_serving = 0;
static thread_local unsigned    guard_depth = 0;
#endif

RazerDeviceGuard::RazerDeviceGuard() : DeviceGuard()
{
#ifdef _WIN32
    mutex_handle = CreateWindowsMutex();
#endif
}

void RazerDeviceGuard::Acquire()
{
#ifdef _WIN32
    /*-----------------------------------------------------------------*\
    | Already held by this thread: only count the nesting               |
    \*-----------------------------------------------------------------*/
    if(guard_depth > 0)
    {
        guard_depth++;
        return;
    }

    /*-----------------------------------------------------------------*\
    | Wait for our turn among this process's threads first.  The        |
    | Windows mutex is not fair: a thread that releases it and asks     |
    | again right away (a keyboard sending its rows back to back) gets  |
    | it again ahead of a thread that was already waiting (a mouse),    |
    | which then starves for whole frames.                              |
    \*-----------------------------------------------------------------*/
    {
        std::unique_lock<std::mutex> turn_lock(turn_mutex);
        unsigned long long           ticket = next_ticket++;

        turn_cv.wait(turn_lock, [ticket]{ return(ticket == now_serving); });
    }

    /*-----------------------------------------------------------------*\
    | Then wait for other processes (e.g. Razer's own software)         |
    \*-----------------------------------------------------------------*/
    while(true)
    {
        DWORD result = WaitForSingleObject(mutex_handle, INFINITE);

        if(result == WAIT_OBJECT_0)
        {
            break;
        }

        if(result == WAIT_ABANDONED)
        {
            ReleaseMutex(mutex_handle);
        }
    }

    guard_depth = 1;
#endif
}

void RazerDeviceGuard::Release()
{
#ifdef _WIN32
    if(--guard_depth > 0)
    {
        return;
    }

    ReleaseMutex(mutex_handle);

    {
        std::lock_guard<std::mutex> turn_lock(turn_mutex);
        now_serving++;
    }

    turn_cv.notify_all();
#endif
}

#ifdef _WIN32

HANDLE RazerDeviceGuard::CreateWindowsMutex()
{
    SECURITY_DESCRIPTOR sd;
    InitializeSecurityDescriptor(&sd, SECURITY_DESCRIPTOR_REVISION);
    SetSecurityDescriptorDacl(&sd, TRUE, NULL, FALSE);

    SECURITY_ATTRIBUTES sa;
    sa.nLength = sizeof(SECURITY_ATTRIBUTES);
    sa.lpSecurityDescriptor = &sd;
    sa.bInheritHandle = FALSE;

    return CreateMutex(&sa, FALSE, "Global\\RazerLinkReadWriteGuardMutex");
}

#endif
